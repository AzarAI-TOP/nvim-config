# scripts/bootstrap-windows.ps1 的安全逻辑测试。
#
# 这些测试绝不运行 winget、rustup、安装器、字体下载，
# 也绝不触碰真实的用户/系统 PATH 或注册表。引导脚本被 dot-source
# （它只定义函数；绝不允许自动执行），每个原生命令都被注入的假执行器
# 替换，PATH I/O 被内存假实现替换。
#
# 可在 Windows PowerShell 5.1 与 PowerShell 7 上运行（不依赖 Pester）。
#
# 用法：
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-bootstrap-windows.ps1
#   pwsh -NoProfile -File ./scripts/test-bootstrap-windows.ps1

$ErrorActionPreference = "Stop"

$bootstrapScript = Join-Path $PSScriptRoot "bootstrap-windows.ps1"
if (-not (Test-Path -LiteralPath $bootstrapScript)) {
    throw "未找到引导脚本 '$bootstrapScript'"
}

$script:originalProcessPath = $env:Path
$script:passCount = 0
$script:failCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -ne $Actual) {
        throw "$Message（期望 '$Expected'，实际 '$Actual'）"
    }
}

function Assert-Throws {
    param(
        [scriptblock]$Action,
        [string]$Message,
        [string[]]$ExpectedFragments = @()
    )
    $threw = $false
    try {
        & $Action
    } catch {
        $threw = $true
        foreach ($fragment in $ExpectedFragments) {
            if ($_.Exception.Message -notlike "*$fragment*") {
                throw "${Message}：异常消息缺少片段 '$fragment'。实际：$($_.Exception.Message)"
            }
        }
    }
    if (-not $threw) {
        throw "${Message}：期望抛出异常，但未抛出"
    }
}

function Invoke-Test {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:passCount++
        Write-Host "[通过] $Name"
    } catch {
        $script:failCount++
        Write-Host "[失败] $Name"
        Write-Host "       $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# 共享假实现。每个编排测试先重置状态，因此测试之间互不依赖，
# 也不会触碰真实环境。
# ---------------------------------------------------------------------------

$script:calls = @()          # 记录的 "$command $args" 调用
$script:notified = @()       # 发给 Notify 接收器的消息
$script:failPackageId = ""   # 应失败（退出码 1）的 winget 包 id
$script:userPathStore = ""   # 模拟的用户 PATH
$script:pathWriteCount = 0   # 模拟用户 PATH 被写入的次数
$script:neovideExePresent = $true  # C:\Program Files\Neovide\neovide.exe 是否存在

$script:runner = {
    param($command, $arguments)
    $script:calls += "$command $($arguments -join ' ')"
    if ($script:failPackageId -and ($arguments -contains $script:failPackageId)) {
        $global:LASTEXITCODE = 1
    } else {
        $global:LASTEXITCODE = 0
    }
}

# neovide.exe 只有在其 winget 安装运行后才存在
# （模拟干净的首次运行：安装前可执行文件不存在）。
$script:testPath = {
    param($path)
    if ($path -like "*neovide.exe") {
        return [bool]($script:neovideExePresent -and ($script:calls -like "*winget*Neovide.Neovide*"))
    }
    return $false
}

# winget/nvim 始终存在；neovide 只有在其目录进入（模拟的）用户 PATH 后
# 才可解析，如同修复后的真实 Get-Command 查找。
$script:testCommand = {
    param($name)
    if ($name -eq "winget") { return $true }
    if ($name -eq "nvim") { return $true }
    if ($name -eq "neovide") {
        return [bool]((@($script:userPathStore -split ";" | Where-Object { $_ -ieq "C:\Program Files\Neovide" }).Count -gt 0))
    }
    return $false
}

$script:readUserPath = { param() $script:userPathStore }
$script:writeUserPath = {
    param($value)
    $script:userPathStore = $value
    $script:pathWriteCount++
}
$script:notify = { param($message) $script:notified += $message }
$script:shortcutCalls = @()
$script:fakeShortcutFactory = {
    param($path, $target, $hotkey)
    $script:shortcutCalls += @{ Path = $path; TargetPath = $target; Hotkey = $hotkey }
    return $null
}

function Reset-TestState {
    $script:calls = @()
    $script:notified = @()
    $script:failPackageId = ""
    $script:userPathStore = ""
    $script:pathWriteCount = 0
    $script:neovideExePresent = $true
    $script:shortcutCalls = @()
}

try {
    # 加载引导辅助函数。必须只定义函数/状态：若自动执行，
    # 真实引导会运行，下面的测试要么大声失败要么执行真实安装。
    . $bootstrapScript

    if (-not (Get-Command Invoke-BootstrapWindows -ErrorAction SilentlyContinue)) {
        throw "dot-source 未定义 Invoke-BootstrapWindows"
    }
    if (-not (Get-Command Invoke-NativeChecked -ErrorAction SilentlyContinue)) {
        throw "dot-source 未定义 Invoke-NativeChecked"
    }

    # --- 1. 原生命令成功：输出保留、不抛出 --------------------------------
    Invoke-Test -Name "原生命令成功保留输出" -Body {
        $fake = { param($command, $arguments) $global:LASTEXITCODE = 0; "fake-native-output" }
        $output = Invoke-NativeChecked -Command "winget" -Arguments @("--version") -AcceptableExitCodes @(0) -Executor $fake
        Assert-True ($output -match "fake-native-output") "原生 stdout 必须保留"
    }

    # --- 2. 原生命令失败：抛出命令与上下文 --------------------------------
    Invoke-Test -Name "原生命令失败抛出命令、退出码与上下文" -Body {
        $fake = { param($command, $arguments) $global:LASTEXITCODE = 5 }
        Assert-Throws {
            Invoke-NativeChecked -Command "winget" `
                -Arguments @("install", "--id", "Git.Git") `
                -AcceptableExitCodes @(0) `
                -Context "winget package 'Git.Git'" `
                -Executor $fake
        } -Message "不可接受的退出码必须抛出" `
          -ExpectedFragments @("winget install --id Git.Git", "退出码 5", "Git.Git")
    }

    # --- 3. 文档记载的 winget 幂等退出码被接受 -----------------------------
    Invoke-Test -Name "文档记载的 winget 幂等退出码被接受" -Body {
        Assert-Equal 3 $script:WingetInstallAcceptableExitCodes.Count "0 + INSTALL_ALREADY_INSTALLED + INSTALL_DOWNGRADE"
        foreach ($code in $script:WingetInstallAcceptableExitCodes) {
            $expected = $code
            $fake = { param($command, $arguments) $global:LASTEXITCODE = $expected }
            $null = Invoke-NativeChecked -Command "winget" `
                -Arguments @("install", "--id", "Git.Git") `
                -AcceptableExitCodes $script:WingetInstallAcceptableExitCodes `
                -Context "winget package 'Git.Git'" `
                -Executor $fake
        }
    }

    # --- 4. 一个包失败即停止后续包与成功消息 -------------------------------
    Invoke-Test -Name "包失败停止后续包且不发送成功消息" -Body {
        Reset-TestState
        $script:failPackageId = "Neovim.Neovim"
        $script:userPathStore = "C:\Existing\Bin"

        Assert-Throws {
            Invoke-BootstrapWindows `
                -Packages @("Git.Git", "Neovim.Neovim", "Neovide.Neovide") `
                -Executor $script:runner `
                -SkipFont `
                -ShortcutFactory $script:fakeShortcutFactory `
                -Notify $script:notify `
                -TestCommand $script:testCommand `
                -TestPath $script:testPath `
                -ReadUserPath $script:readUserPath `
                -WriteUserPath $script:writeUserPath `
                -NvimVersionOutput "NVIM v0.12.4"
        } -Message "winget 失败必须中止引导" `
          -ExpectedFragments @("Neovim.Neovim", "退出码 1")

        Assert-True (($script:calls -like "*winget*Git.Git*").Count -gt 0) "第一个包必须运行"
        Assert-True (($script:calls -like "*winget*Neovim.Neovim*").Count -gt 0) "失败的包必须被尝试"
        Assert-True (($script:calls -like "*winget*Neovide.Neovide*").Count -eq 0) "失败之后的包不得运行"
        Assert-True (($script:calls -like "*MasonToolsInstallSync*").Count -eq 0) "Mason 步骤不得运行"
        Assert-True ($script:notified.Count -eq 0) "失败后不得有最终成功消息"
    }

    # --- 5. 干净的首次运行：模拟安装后加入 Neovide PATH ---------------------
    Invoke-Test -Name "干净的首次运行在模拟安装后加入 Neovide PATH 条目" -Body {
        Reset-TestState
        $script:userPathStore = "C:\Existing\Bin"

        $null = Invoke-BootstrapWindows `
            -Packages @("Neovide.Neovide") `
            -Executor $script:runner `
            -SkipFont `
            -ShortcutFactory $script:fakeShortcutFactory `
            -Notify $script:notify `
            -TestCommand $script:testCommand `
            -TestPath $script:testPath `
            -ReadUserPath $script:readUserPath `
            -WriteUserPath $script:writeUserPath `
            -NvimVersionOutput "NVIM v0.12.4"

        Assert-Equal 1 $script:pathWriteCount "用户 PATH 必须恰好写入一次"
        $segments = @($script:userPathStore -split ";" | Where-Object { $_ })
        Assert-Equal 2 $segments.Count "一个无关条目加一个新条目"
        Assert-Equal "C:\Existing\Bin" $segments[0] "无关条目必须保留"
        Assert-True ($segments -contains "C:\Program Files\Neovide") "Neovide 目录必须被加入"
        Assert-Equal 1 $script:shortcutCalls.Count "首次运行必须请求创建快捷方式"
        Assert-Equal "Ctrl+Alt+N" $script:shortcutCalls[0].Hotkey "快捷方式热键必须是 Ctrl+Alt+N"
        Assert-True ($script:notified.Count -eq 1) "必须出现成功消息"
        Assert-True ($script:notified[0] -like "*引导完成*") "成功消息必须是完成通知"
    }

    # --- 6. 重复运行：不重复添加、不再次写入 -------------------------------
    Invoke-Test -Name "重复运行不添加重复条目且不重写 PATH" -Body {
        Reset-TestState
        $script:userPathStore = "C:\Existing\Bin"

        $null = Invoke-BootstrapWindows `
            -Packages @("Neovide.Neovide") `
            -Executor $script:runner `
            -SkipFont `
            -ShortcutFactory $script:fakeShortcutFactory `
            -Notify $script:notify `
            -TestCommand $script:testCommand `
            -TestPath $script:testPath `
            -ReadUserPath $script:readUserPath `
            -WriteUserPath $script:writeUserPath `
            -NvimVersionOutput "NVIM v0.12.4"
        Assert-Equal 1 $script:pathWriteCount "首次运行写入一次"

        $null = Invoke-BootstrapWindows `
            -Packages @("Neovide.Neovide") `
            -Executor $script:runner `
            -SkipFont `
            -ShortcutFactory $script:fakeShortcutFactory `
            -Notify $script:notify `
            -TestCommand $script:testCommand `
            -TestPath $script:testPath `
            -ReadUserPath $script:readUserPath `
            -WriteUserPath $script:writeUserPath `
            -NvimVersionOutput "NVIM v0.12.4"

        Assert-Equal 1 $script:pathWriteCount "第二次运行不得再写入"
        $neovideEntries = @($script:userPathStore -split ";" | Where-Object { $_ -ieq "C:\Program Files\Neovide" })
        Assert-Equal 1 $neovideEntries.Count "恰好一个 Neovide 条目"
        Assert-True ($script:userPathStore -like "C:\Existing\Bin*") "无关条目仍在"
    }

    # --- 7. 已在 PATH 上：原样保留 -----------------------------------------
    Invoke-Test -Name "已在 PATH 上的 Neovide 原样保留" -Body {
        Reset-TestState
        $script:userPathStore = "C:\Existing\Bin;C:\Program Files\Neovide"

        $null = Invoke-BootstrapWindows `
            -Packages @("Neovide.Neovide") `
            -Executor $script:runner `
            -SkipFont `
            -ShortcutFactory $script:fakeShortcutFactory `
            -Notify $script:notify `
            -TestCommand $script:testCommand `
            -TestPath $script:testPath `
            -ReadUserPath $script:readUserPath `
            -WriteUserPath $script:writeUserPath `
            -NvimVersionOutput "NVIM v0.12.4"

        Assert-Equal 0 $script:pathWriteCount "已可解析时不写 PATH"
        Assert-Equal "C:\Existing\Bin;C:\Program Files\Neovide" $script:userPathStore "用户 PATH 不变"
    }

    # --- 8. 可执行文件缺失：抛出、不假装成功、不写 PATH --------------------
    Invoke-Test -Name "Neovide 可执行文件缺失时抛出且不写 PATH" -Body {
        Reset-TestState
        $script:neovideExePresent = $false
        $script:userPathStore = "C:\Existing\Bin"

        Assert-Throws {
            Invoke-BootstrapWindows `
                -Packages @("Neovide.Neovide") `
                -Executor $script:runner `
                -SkipFont `
                -ShortcutFactory $script:fakeShortcutFactory `
                -Notify $script:notify `
                -TestCommand $script:testCommand `
                -TestPath $script:testPath `
                -ReadUserPath $script:readUserPath `
                -WriteUserPath $script:writeUserPath `
                -NvimVersionOutput "NVIM v0.12.4"
        } -Message "Neovide 可执行文件缺失必须使引导失败" `
          -ExpectedFragments @("Neovide", "neovide.exe")

        Assert-Equal 0 $script:pathWriteCount "可执行文件缺失时不写 PATH"
        Assert-Equal "C:\Existing\Bin" $script:userPathStore "用户 PATH 不变"
        Assert-True ($script:notified.Count -eq 0) "Neovide 缺失时无成功消息"
    }

    # --- 9. 拒绝 Neovim 0.11，接受 0.12 ------------------------------------
    Invoke-Test -Name "拒绝 Neovim 0.11 并报告检测到的与要求的版本" -Body {
        try {
            $null = Assert-NeovimMinimumVersion -VersionOutput "NVIM v0.11.4" -MinimumVersion "0.12.0"
            throw "期望 0.11 被拒绝"
        } catch {
            if ($_.Exception.Message -notlike "*0.11.4*") {
                throw "错误必须报告检测到的版本；实际：$($_.Exception.Message)"
            }
            if ($_.Exception.Message -notlike "*0.12.0*") {
                throw "错误必须报告要求的版本；实际：$($_.Exception.Message)"
            }
        }
    }

    Invoke-Test -Name "接受 Neovim 0.12" -Body {
        $detected = Assert-NeovimMinimumVersion -VersionOutput "NVIM v0.12.4" -MinimumVersion "0.12.0"
        Assert-Equal "v0.12.4" $detected
        $devDetected = Assert-NeovimMinimumVersion -VersionOutput "NVIM v0.12.0-dev-1234+gabc1234" -MinimumVersion "0.12.0"
        Assert-Equal "v0.12.0" $devDetected
        $newerDetected = Assert-NeovimMinimumVersion -VersionOutput "NVIM v0.13.1" -MinimumVersion "0.12.0"
        Assert-Equal "v0.13.1" $newerDetected
    }

    # --- 11. Add-PathEntryString：幂等、保序、去重 --------------------------
    Invoke-Test -Name "PATH 条目辅助函数幂等且保留无关条目" -Body {
        $result = Add-PathEntryString -PathValue "C:\A;C:\B;" -Entry "C:\Program Files\Neovide"
        Assert-Equal "C:\A;C:\B;C:\Program Files\Neovide" $result "追加时丢弃空段"
        $again = Add-PathEntryString -PathValue $result -Entry "C:\Program Files\Neovide"
        Assert-True ($again -ceq $result) "重复调用必须是空操作"
        $mixed = Add-PathEntryString -PathValue "c:\program files\neovide;C:\A" -Entry "C:\Program Files\Neovide"
        Assert-True ($mixed -ceq "c:\program files\neovide;C:\A") "已存在条目（不分大小写）必须原样保留"
    }

    # --- 12. Read-VersionsFile：对共享 versions.sh 的宽容解析 --------------
    Invoke-Test -Name "版本文件解析器容忍 CRLF、注释与空行" -Body {
        $tmp = [IO.Path]::GetTempFileName()
        Set-Content -LiteralPath $tmp -Value "# pinned assets`r`n`r`nNVIM_VERSION=`"0.12.4`"`r`nOXPROTO_SHA256_ZIP=`"abc123`"" -NoNewline
        try {
            $v = Read-VersionsFile -Path $tmp
            Assert-Equal "0.12.4" $v.NVIM_VERSION "NVIM_VERSION 必须能穿过 CRLF 解析"
            Assert-Equal "abc123" $v.OXPROTO_SHA256_ZIP "OXPROTO_SHA256_ZIP 必须能解析"
            Assert-Equal 2 $v.Count "解析器必须恰好产出声明的键"
        } finally {
            Remove-Item -LiteralPath $tmp -Force
        }
    }

    Invoke-Test -Name "格式错误的版本文件行大声失败" -Body {
        $tmp = [IO.Path]::GetTempFileName()
        Set-Content -LiteralPath $tmp -Value "NVIM_VERSION=0.12.4" -NoNewline
        try {
            Assert-Throws -Action { $null = Read-VersionsFile -Path $tmp } `
                -Message "未加引号的值必须被拒绝" -ExpectedFragments @("格式错误")
        } finally {
            Remove-Item -LiteralPath $tmp -Force
        }
    }

    Invoke-Test -Name "共享版本文件提供 Windows 字体版本与哈希" -Body {
        $v = Read-VersionsFile -Path (Join-Path $script:BootstrapDir "versions.sh")
        Assert-True ($v.NERD_FONTS_VERSION -match '^\d+\.\d+\.\d+$') "NERD_FONTS_VERSION 必须固定"
        Assert-True ($v.OXPROTO_SHA256_ZIP.Length -eq 64) "OXPROTO_SHA256_ZIP 必须是 SHA-256"
        Assert-True ($v.OXPROTO_SHA256_XZ.Length -eq 64) "OXPROTO_SHA256_XZ 必须是 SHA-256"
        Assert-True ($v.OXPROTO_SHA256_XZ -ne $v.OXPROTO_SHA256_ZIP) "zip/xz 压缩包必须哈希不同"
    }

    # --- 13. Neovide 快捷方式：热键契约 + 可注入 COM 工厂 -------------------
    Invoke-Test -Name "热键归一化忽略修饰键顺序" -Body {
        Assert-Equal "alt+ctrl+n" (Get-NormalizedHotkey "Alt+Ctrl+N")
        Assert-Equal "alt+ctrl+n" (Get-NormalizedHotkey "Ctrl+Alt+N")
        Assert-Equal "" (Get-NormalizedHotkey "")
    }

    Invoke-Test -Name "Neovide 快捷方式工厂按文档契约被调用" -Body {
        Reset-TestState
        $factory = {
            param($path, $target, $hotkey)
            $script:shortcutCalls += @{ Path = $path; TargetPath = $target; Hotkey = $hotkey }
            return @{ Path = $path; TargetPath = $target; Hotkey = $hotkey }
        }
        $result = New-NeovideShortcut -TargetPath "C:\Program Files\Neovide\neovide.exe" `
            -ShortcutFactory $factory -TestPath { param($p) $true }
        Assert-Equal 1 $script:shortcutCalls.Count "工厂必须恰好运行一次"
        Assert-Equal "Ctrl+Alt+N" $script:shortcutCalls[0].Hotkey "热键必须是 Ctrl+Alt+N"
        Assert-Equal "C:\Program Files\Neovide\neovide.exe" $script:shortcutCalls[0].TargetPath "目标必须是 neovide.exe"
        Assert-True ($script:shortcutCalls[0].Path -like "*Neovide.lnk") "快捷方式必须落在开始菜单"
        Assert-Equal "Ctrl+Alt+N" $result.Hotkey "必须返回工厂结果"
    }

    Invoke-Test -Name "Neovide 快捷方式在可执行文件缺失时拒绝创建" -Body {
        Assert-Throws -Action {
            New-NeovideShortcut -TargetPath "C:\Missing\neovide.exe" -TestPath { param($p) $false }
        } -Message "可执行文件缺失必须失败" -ExpectedFragments @("未找到")
    }
} finally {
    $env:Path = $script:originalProcessPath
}

Write-Host ""
Write-Host "通过: $($script:passCount)  失败: $($script:failCount)"
if ($script:failCount -gt 0) {
    exit 1
}
