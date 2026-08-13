# 引导 Windows 的系统级依赖。在 PowerShell 中运行。
# Mason 负责安装 LSP 服务器与便携格式化器。
#
# 脚本被 dot-source 时只定义函数与状态，便于在隔离环境中安全加载；
# 只有直接调用时才执行 Invoke-BootstrapWindows。
#
# 行为保证：
#  - 每个关键原生命令（winget、rustup、nvim）都经 Invoke-NativeChecked
#    执行，遇到不可接受的退出码立即失败。
#  - 一个包失败即中止引导：后续包、Mason 步骤与最终成功消息全部跳过。
#  - Neovide PATH 修复在安装与进程 PATH 刷新之后执行，
#    干净的首次运行才能真正修复。
#  - 安装后要求 Neovim 0.12.0 或更新。

$ErrorActionPreference = "Stop"

$script:DefaultPackages = @(
    "Git.Git",
    "Neovim.Neovim",
    "Neovide.Neovide",
    "BurntSushi.ripgrep.MSVC",
    "junegunn.fzf",
    "OpenJS.NodeJS.LTS",
    "Python.Python.3.13",
    "GoLang.Go",
    "Rustlang.Rustup",
    "Microsoft.OpenJDK.21",
    "LLVM.LLVM",
    "7zip.7zip"
)

# 有文档记载的 winget 安装退出码：对幂等引导而言仍代表"包已就位"。
# 来源：microsoft/winget-cli，src/AppInstallerSharedLib/Public/AppInstallerErrors.h
#   0x8A15010D APPINSTALLER_CLI_ERROR_INSTALL_ALREADY_INSTALLED
#   0x8A15010E APPINSTALLER_CLI_ERROR_INSTALL_DOWNGRADE
#              （已安装更新版本）
# 其余退出码一律使引导失败。十六进制值通过位模式转换，
# 使有符号 Int32 结果在 PowerShell 5.1 与 7 上完全一致
# （5.1 拒绝直接的收窄 [int] 转换）。
function ConvertTo-Int32FromHex32 {
    param([Parameter(Mandatory)][string]$Hex)
    return [BitConverter]::ToInt32(
        [BitConverter]::GetBytes([uint32]::Parse($Hex, [System.Globalization.NumberStyles]::HexNumber)),
        0)
}

$script:BootstrapDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Read-VersionsFile {
    # 解析 KEY="VALUE" 形式的版本文件（scripts/versions.sh），但不执行它。
    # 容忍 CRLF 行尾、空行与 # 注释。
    # 未知或格式错误的行视为错误，避免版本漂移静默失效。
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "未找到版本文件 '$Path'"
    }
    $result = @{}
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        if ($trimmed -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]*)"$') {
            $result[$Matches[1]] = $Matches[2]
        } else {
            throw "版本文件行格式错误：'$line'"
        }
    }
    return $result
}

function Get-NormalizedHotkey {
    # WScript.Shell 用自己的一套修饰键顺序序列化 .lnk 热键
    # （例如写入 "Ctrl+Alt+N" 读回 "Alt+Ctrl+N"）；
    # 因此比较语义键集合而非字符串。
    param([AllowEmptyString()][string]$Value)
    return (@($Value.ToLowerInvariant() -split "\+" | Where-Object { $_ } | Sort-Object) -join "+")
}

$script:DefaultShortcutFactory = {
    # 创建快捷方式；当已存在带请求热键的快捷方式时跳过（返回 $null）。
    # 使用 WScript.Shell COM。
    param($lnkPath, $target, $hotkey)
    $shell = New-Object -ComObject WScript.Shell
    if (Test-Path -LiteralPath $lnkPath) {
        $existing = $shell.CreateShortcut($lnkPath)
        if ((Get-NormalizedHotkey $existing.Hotkey) -eq (Get-NormalizedHotkey $hotkey)) {
            return $null
        }
    }
    $dir = Split-Path -Parent $lnkPath
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $shortcut = $shell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = $target
    $shortcut.Hotkey = $hotkey
    $shortcut.Save()
    return @{ Path = $lnkPath; TargetPath = $target; Hotkey = $hotkey }
}

function New-NeovideShortcut {
    # 创建文档记载的 Ctrl+Alt+N 开始菜单 Neovide 启动器。
    # COM 工厂可注入，逻辑测试因此绝不触碰真实的开始菜单或注册表。
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$TargetPath = "C:\Program Files\Neovide\neovide.exe",
        [string]$ShortcutPath = "",
        [string]$Hotkey = "Ctrl+Alt+N",
        [scriptblock]$ShortcutFactory = $null,
        [scriptblock]$TestPath = { param($path) Test-Path -LiteralPath $path }
    )
    if (-not $ShortcutPath) {
        $ShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Neovide.lnk"
    }
    if (-not (& $TestPath $TargetPath)) {
        throw "在 '$TargetPath' 未找到 Neovide 可执行文件，无法创建开始菜单快捷方式。"
    }
    if ($null -eq $ShortcutFactory) {
        $ShortcutFactory = $script:DefaultShortcutFactory
    }
    if (-not $PSCmdlet.ShouldProcess($ShortcutPath, "创建带热键 $Hotkey 的 Neovide 快捷方式")) {
        return $null
    }
    return & $ShortcutFactory $ShortcutPath $TargetPath $Hotkey
}

$script:WingetInstallAcceptableExitCodes = @(
    0,
    (ConvertTo-Int32FromHex32 "8A15010D"),
    (ConvertTo-Int32FromHex32 "8A15010E")
)

function Invoke-NativeChecked {
    # 运行原生命令（或注入的假执行器）、保留其输出，
    # 退出码不可接受时抛出带命令/上下文信息的异常。
    # 仅靠 $ErrorActionPreference = "Stop" 不会在
    # 原生命令非零退出码时失败。
    param(
        [Parameter(Mandatory)][string]$Command,
        [string[]]$Arguments = @(),
        [int[]]$AcceptableExitCodes = @(0),
        [string]$Context = "",
        [scriptblock]$Executor = $null
    )
    if ($null -eq $Executor) {
        & $Command @Arguments
    } else {
        & $Executor $Command $Arguments
    }
    $exitCode = $LASTEXITCODE
    if ($AcceptableExitCodes -notcontains $exitCode) {
        $argumentsText = if ($Arguments.Count -gt 0) { " $($Arguments -join ' ')" } else { "" }
        $contextText = if ($Context) { "（$Context）" } else { "" }
        throw "命令 '$Command$argumentsText' 失败，退出码 $exitCode。$contextText"
    }
}

function Add-PathEntryString {
    # 纯辅助函数：返回恰好包含 $Entry 一次的 PATH 字符串。
    # 无关条目保持原顺序；仅追加时丢弃空段。
    # 已存在的条目（不分大小写）原样保留，重复调用为空操作。
    param(
        [Parameter(Mandatory)][string]$PathValue,
        [Parameter(Mandatory)][string]$Entry
    )
    $segments = @($PathValue -split ";" | Where-Object { $_ })
    $cleaned = @()
    foreach ($segment in $segments) {
        if ([string]::Equals($segment, $Entry, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $PathValue
        }
        $cleaned += $segment
    }
    $cleaned += $Entry
    return ($cleaned -join ";")
}

function Add-UserPathEntry {
    # 把 $Directory 恰好一次加入用户 PATH，保留无关条目。
    # I/O 可注入，测试因此绝不触碰真实的用户 PATH。
    param(
        [Parameter(Mandatory)][string]$Directory,
        [scriptblock]$ReadPath = { [Environment]::GetEnvironmentVariable("Path", "User") },
        [scriptblock]$WritePath = { param($value) [Environment]::SetEnvironmentVariable("Path", $value, "User") }
    )
    $current = & $ReadPath
    if ($null -eq $current) { $current = "" }
    $updated = Add-PathEntryString -PathValue $current -Entry $Directory
    if ($updated -ne $current) {
        & $WritePath $updated
    }
    return $updated
}

function Repair-NeovidePath {
    # Neovide 安装到 $NeovideDirectory，但 winget 包不把它加入 PATH。
    # 把目录恰好一次加入用户 PATH、刷新进程 PATH，
    # 之后若可执行文件缺失或仍无法解析则抛出异常（不假装成功）。
    param(
        [string]$NeovideDirectory = "C:\Program Files\Neovide",
        [scriptblock]$TestPath = { param($path) Test-Path -LiteralPath $path },
        [scriptblock]$TestCommand = { param($name) Get-Command $name -ErrorAction SilentlyContinue },
        [scriptblock]$ReadUserPath = { [Environment]::GetEnvironmentVariable("Path", "User") },
        [scriptblock]$WriteUserPath = { param($value) [Environment]::SetEnvironmentVariable("Path", $value, "User") }
    )
    $neovideExe = Join-Path $NeovideDirectory "neovide.exe"
    if (-not (& $TestPath $neovideExe)) {
        throw "winget 安装后在 '$neovideExe' 未找到 Neovide 可执行文件。Neovide 安装不正确；请重新运行引导。"
    }
    if (& $TestCommand "neovide") {
        return
    }
    $null = Add-UserPathEntry -Directory $NeovideDirectory -ReadPath $ReadUserPath -WritePath $WriteUserPath
    $env:Path = Add-PathEntryString -PathValue $env:Path -Entry $NeovideDirectory
    if (-not (& $TestCommand "neovide")) {
        throw "Neovide 已安装，但更新 PATH 后仍无法解析。请打开新的 PowerShell 窗口并重新运行引导。"
    }
}

function Assert-NeovimMinimumVersion {
    # 已安装 Neovim 低于 $MinimumVersion 时抛出检测到的与要求的版本；
    # 成功时返回检测到的版本。
    param(
        [Parameter(Mandatory)][string]$VersionOutput,
        [string]$MinimumVersion = "0.12.0"
    )
    if ($VersionOutput -notmatch "NVIM v(?<major>[0-9]+)\.(?<minor>[0-9]+)\.(?<patch>[0-9]+)") {
        $firstLine = ($VersionOutput -split "`r?`n" | Where-Object { $_ } | Select-Object -First 1)
        throw "无法从输出（'$firstLine'）确定 Neovim 版本，无法验证 $MinimumVersion 最低要求。"
    }
    $detectedVersion = "v$($Matches['major']).$($Matches['minor']).$($Matches['patch'])"
    $minimumParts = $MinimumVersion -split "\."
    $detectedMajor = [int]$Matches['major']
    $detectedMinor = [int]$Matches['minor']
    $minimumMajor = [int]$minimumParts[0]
    $minimumMinor = [int]$minimumParts[1]
    if ($detectedMajor -lt $minimumMajor -or
        ($detectedMajor -eq $minimumMajor -and $detectedMinor -lt $minimumMinor)) {
        throw "检测到 Neovim $detectedVersion，但需要 $MinimumVersion 或更新版本。请更新 Neovim 后重新运行引导。"
    }
    return $detectedVersion
}

function Invoke-BootstrapWindows {
    param(
        [string[]]$Packages = $null,
        [scriptblock]$Executor = $null,
        [scriptblock]$TestCommand = { param($name) Get-Command $name -ErrorAction SilentlyContinue },
        [scriptblock]$TestPath = { param($path) Test-Path -LiteralPath $path },
        [scriptblock]$ReadUserPath = { [Environment]::GetEnvironmentVariable("Path", "User") },
        [scriptblock]$WriteUserPath = { param($value) [Environment]::SetEnvironmentVariable("Path", $value, "User") },
        [switch]$SkipFont,
        [string]$NvimVersionOutput = "",
        [scriptblock]$Notify = { param($message) Write-Output $message },
        [string]$VersionsPath = "",
        [scriptblock]$ShortcutFactory = $null
    )
    if ($null -eq $Packages) { $Packages = $script:DefaultPackages }

    if ($VersionsPath) {
        $script:Versions = Read-VersionsFile -Path $VersionsPath
    } else {
        $script:Versions = Read-VersionsFile -Path (Join-Path $script:BootstrapDir "versions.sh")
    }

    if (-not (& $TestCommand "winget")) {
        throw "需要 winget。请先安装或更新 Microsoft App Installer。"
    }

    foreach ($package in $Packages) {
        Invoke-NativeChecked -Command "winget" `
            -Arguments @("install", "--id", $package, "--exact", "--accept-package-agreements", "--accept-source-agreements") `
            -AcceptableExitCodes $script:WingetInstallAcceptableExitCodes `
            -Context "winget package '$package'" `
            -Executor $Executor
    }

    # 安装器更新注册表环境后刷新当前进程。
    $env:Path = @(
        [Environment]::GetEnvironmentVariable("Path", "Machine"),
        [Environment]::GetEnvironmentVariable("Path", "User")
    ) -join ";"

    # Neovide PATH 修复必须在安装与 PATH 刷新之后执行，
    # 干净的首次运行才能真正修复。
    Repair-NeovidePath -NeovideDirectory "C:\Program Files\Neovide" `
        -TestPath $TestPath -TestCommand $TestCommand `
        -ReadUserPath $ReadUserPath -WriteUserPath $WriteUserPath

    # 带文档记载的 Ctrl+Alt+N 热键的开始菜单快捷方式。幂等：
    # 已存在该热键的快捷方式时工厂跳过创建。
    $null = New-NeovideShortcut `
        -TargetPath "C:\Program Files\Neovide\neovide.exe" `
        -ShortcutFactory $ShortcutFactory `
        -TestPath $TestPath

    # 部分 winget 版本创建便携 fzf 包但遗漏其 PATH 目录。
    # 幂等地为当前进程与未来 shell 修复。
    $fzfDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\junegunn.fzf_Microsoft.Winget.Source_8wekyb3d8bbwe"
    if ((& $TestPath (Join-Path $fzfDirectory "fzf.exe")) -and -not (& $TestCommand "fzf")) {
        $null = Add-UserPathEntry -Directory $fzfDirectory -ReadPath $ReadUserPath -WritePath $WriteUserPath
        $env:Path = Add-PathEntryString -PathValue $env:Path -Entry $fzfDirectory
    }

    if (-not $SkipFont) {
        # 安装与 Fedora 上 Neovide 相同的按用户 Nerd Font。
        $fontRegistry = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
        $fontInstalled = @(
            "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts",
            "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
        ) | Where-Object { (Get-ItemProperty -Path $_ -ErrorAction SilentlyContinue | Out-String) -match "0xProto" }
        if (-not $fontInstalled) {
            $fontTemp = Join-Path ([IO.Path]::GetTempPath()) ("0xProto-" + [guid]::NewGuid())
            $fontArchive = Join-Path $fontTemp "0xProto.zip"
            $fontSource = Join-Path $fontTemp "source"
            $fontTarget = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
            New-Item -ItemType Directory -Force -Path $fontSource, $fontTarget | Out-Null
            try {
                Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/download/v$($script:Versions.NERD_FONTS_VERSION)/0xProto.zip" -OutFile $fontArchive
                $fontHash = (Get-FileHash -Path $fontArchive -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($fontHash -ne $script:Versions.OXPROTO_SHA256_ZIP) {
                    throw "0xProto 压缩包校验和不匹配"
                }
                Expand-Archive -Path $fontArchive -DestinationPath $fontSource -Force
                New-Item -Path $fontRegistry -Force | Out-Null
                Get-ChildItem -Path $fontSource -Filter "*.ttf" | ForEach-Object {
                    $destination = Join-Path $fontTarget $_.Name
                    Copy-Item $_.FullName $destination -Force
                    New-ItemProperty -Path $fontRegistry -Name ($_.BaseName + " (TrueType)") -Value $destination -PropertyType String -Force | Out-Null
                }
            } finally {
                Remove-Item $fontTemp -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if (& $TestCommand "rustup") {
        Invoke-NativeChecked -Command "rustup" `
            -Arguments @("toolchain", "install", "stable", "--profile", "minimal", "--component", "rustfmt") `
            -Context "rustup stable toolchain" `
            -Executor $Executor
    }

    if (-not (& $TestCommand "nvim")) {
        throw "PATH 中还看不到 nvim。请打开新的 PowerShell 窗口后重新运行本脚本。"
    }

    if (-not $NvimVersionOutput) {
        $NvimVersionOutput = Invoke-NativeChecked -Command "nvim" -Arguments @("--version") -Context "nvim --version" -Executor $Executor
    }
    $null = Assert-NeovimMinimumVersion -VersionOutput $NvimVersionOutput -MinimumVersion "0.12.0"

    $env:NVIM_BOOTSTRAP = "1"
    try {
        Invoke-NativeChecked -Command "nvim" `
            -Arguments @("--headless", "+MasonToolsInstallSync", "+qa!") `
            -Context "Mason tool installation" `
            -Executor $Executor
    } finally {
        $env:NVIM_BOOTSTRAP = $null
    }

    & $Notify "Windows 引导完成。在 Neovim 中运行 :checkhealth 检查环境。"
}

if ($MyInvocation.InvocationName -ne ".") {
    Invoke-BootstrapWindows
}
