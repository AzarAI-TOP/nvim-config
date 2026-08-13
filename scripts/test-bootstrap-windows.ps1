# Safe logic tests for scripts/bootstrap-windows.ps1.
#
# These tests NEVER run winget, rustup, installers, font downloads, or touch
# the real user/system PATH or registry. The bootstrap script is dot-sourced
# (it only defines functions; it must NOT auto-execute), every native command
# is replaced by an injected fake executor, and PATH I/O is replaced by
# in-memory fakes.
#
# Runs on Windows PowerShell 5.1 and PowerShell 7 (no Pester dependency).
#
# Usage:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-bootstrap-windows.ps1
#   pwsh -NoProfile -File ./scripts/test-bootstrap-windows.ps1

$ErrorActionPreference = "Stop"

$bootstrapScript = Join-Path $PSScriptRoot "bootstrap-windows.ps1"
if (-not (Test-Path -LiteralPath $bootstrapScript)) {
    throw "bootstrap script not found at '$bootstrapScript'"
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
        throw "$Message (expected '$Expected', got '$Actual')"
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
                throw "${Message}: exception message is missing fragment '$fragment'. Got: $($_.Exception.Message)"
            }
        }
    }
    if (-not $threw) {
        throw "${Message}: expected an exception, but none was thrown"
    }
}

function Invoke-Test {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:passCount++
        Write-Host "[PASS] $Name"
    } catch {
        $script:failCount++
        Write-Host "[FAIL] $Name"
        Write-Host "       $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# Shared fakes. Every orchestration test resets this state first, so no test
# depends on another and nothing touches the real environment.
# ---------------------------------------------------------------------------

$script:calls = @()          # recorded "$command $args" invocations
$script:notified = @()       # messages sent to the Notify sink
$script:failPackageId = ""   # winget package id that should fail (exit 1)
$script:userPathStore = ""   # simulated user PATH
$script:pathWriteCount = 0   # how many times the simulated user PATH was written
$script:neovideExePresent = $true  # does C:\Program Files\Neovide\neovide.exe exist

$script:runner = {
    param($command, $arguments)
    $script:calls += "$command $($arguments -join ' ')"
    if ($script:failPackageId -and ($arguments -contains $script:failPackageId)) {
        $global:LASTEXITCODE = 1
    } else {
        $global:LASTEXITCODE = 0
    }
}

# neovide.exe exists only after its winget install has run (models a clean
# first run, where the executable is absent before installation).
$script:testPath = {
    param($path)
    if ($path -like "*neovide.exe") {
        return [bool]($script:neovideExePresent -and ($script:calls -like "*winget*Neovide.Neovide*"))
    }
    return $false
}

# winget/nvim are always present; neovide resolves only once its directory is
# in the (simulated) user PATH, like a real Get-Command lookup after repair.
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

function Reset-TestState {
    $script:calls = @()
    $script:notified = @()
    $script:failPackageId = ""
    $script:userPathStore = ""
    $script:pathWriteCount = 0
    $script:neovideExePresent = $true
}

try {
    # Load the bootstrap helpers. Must only define functions/state: if this
    # auto-executed, the real bootstrap would run and the tests below would
    # either fail loudly or perform real installs.
    . $bootstrapScript

    if (-not (Get-Command Invoke-BootstrapWindows -ErrorAction SilentlyContinue)) {
        throw "dot-sourcing did not define Invoke-BootstrapWindows"
    }
    if (-not (Get-Command Invoke-NativeChecked -ErrorAction SilentlyContinue)) {
        throw "dot-sourcing did not define Invoke-NativeChecked"
    }

    # --- 1. native success: output preserved, no throw --------------------
    Invoke-Test -Name "native success preserves output" -Body {
        $fake = { param($command, $arguments) $global:LASTEXITCODE = 0; "fake-native-output" }
        $output = Invoke-NativeChecked -Command "winget" -Arguments @("--version") -AcceptableExitCodes @(0) -Executor $fake
        Assert-True ($output -match "fake-native-output") "native stdout must be preserved"
    }

    # --- 2. native failure: throws with command and context ---------------
    Invoke-Test -Name "native failure throws with command, exit code and context" -Body {
        $fake = { param($command, $arguments) $global:LASTEXITCODE = 5 }
        Assert-Throws {
            Invoke-NativeChecked -Command "winget" `
                -Arguments @("install", "--id", "Git.Git") `
                -AcceptableExitCodes @(0) `
                -Context "winget package 'Git.Git'" `
                -Executor $fake
        } -Message "unacceptable exit code must throw" `
          -ExpectedFragments @("winget install --id Git.Git", "exit code 5", "Git.Git")
    }

    # --- 3. documented winget idempotent codes accepted --------------------
    Invoke-Test -Name "documented winget idempotent exit codes are accepted" -Body {
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

    # --- 4. one failed package stops later packages and the success message -
    Invoke-Test -Name "failed package stops later packages and no success message" -Body {
        Reset-TestState
        $script:failPackageId = "Neovim.Neovim"
        $script:userPathStore = "C:\Existing\Bin"

        Assert-Throws {
            Invoke-BootstrapWindows `
                -Packages @("Git.Git", "Neovim.Neovim", "Neovide.Neovide") `
                -Executor $script:runner `
                -SkipFont `
                -Notify $script:notify `
                -TestCommand $script:testCommand `
                -TestPath $script:testPath `
                -ReadUserPath $script:readUserPath `
                -WriteUserPath $script:writeUserPath `
                -NvimVersionOutput "NVIM v0.12.4"
        } -Message "winget failure must abort the bootstrap" `
          -ExpectedFragments @("Neovim.Neovim", "exit code 1")

        Assert-True (($script:calls -like "*winget*Git.Git*").Count -gt 0) "first package must run"
        Assert-True (($script:calls -like "*winget*Neovim.Neovim*").Count -gt 0) "failed package must be attempted"
        Assert-True (($script:calls -like "*winget*Neovide.Neovide*").Count -eq 0) "packages after the failure must not run"
        Assert-True (($script:calls -like "*MasonToolsInstallSync*").Count -eq 0) "Mason step must not run"
        Assert-True ($script:notified.Count -eq 0) "no final success message after failure"
    }

    # --- 5. clean first run: Neovide PATH added AFTER simulated install ----
    Invoke-Test -Name "clean first run adds Neovide PATH entry after simulated install" -Body {
        Reset-TestState
        $script:userPathStore = "C:\Existing\Bin"

        $null = Invoke-BootstrapWindows `
            -Packages @("Neovide.Neovide") `
            -Executor $script:runner `
            -SkipFont `
            -Notify $script:notify `
            -TestCommand $script:testCommand `
            -TestPath $script:testPath `
            -ReadUserPath $script:readUserPath `
            -WriteUserPath $script:writeUserPath `
            -NvimVersionOutput "NVIM v0.12.4"

        Assert-Equal 1 $script:pathWriteCount "user PATH must be written exactly once"
        $segments = @($script:userPathStore -split ";" | Where-Object { $_ })
        Assert-Equal 2 $segments.Count "unrelated entry plus one new entry"
        Assert-Equal "C:\Existing\Bin" $segments[0] "unrelated entry must be preserved"
        Assert-True ($segments -contains "C:\Program Files\Neovide") "Neovide directory must be added"
        Assert-True ($script:notified.Count -eq 1) "success message must appear"
        Assert-True ($script:notified[0] -like "*complete*") "success message must be the completion notice"
    }

    # --- 6. repeated run: no duplicate entry, no second write --------------
    Invoke-Test -Name "repeated run adds no duplicate and does not rewrite PATH" -Body {
        Reset-TestState
        $script:userPathStore = "C:\Existing\Bin"

        $null = Invoke-BootstrapWindows `
            -Packages @("Neovide.Neovide") `
            -Executor $script:runner `
            -SkipFont `
            -Notify $script:notify `
            -TestCommand $script:testCommand `
            -TestPath $script:testPath `
            -ReadUserPath $script:readUserPath `
            -WriteUserPath $script:writeUserPath `
            -NvimVersionOutput "NVIM v0.12.4"
        Assert-Equal 1 $script:pathWriteCount "first run writes once"

        $null = Invoke-BootstrapWindows `
            -Packages @("Neovide.Neovide") `
            -Executor $script:runner `
            -SkipFont `
            -Notify $script:notify `
            -TestCommand $script:testCommand `
            -TestPath $script:testPath `
            -ReadUserPath $script:readUserPath `
            -WriteUserPath $script:writeUserPath `
            -NvimVersionOutput "NVIM v0.12.4"

        Assert-Equal 1 $script:pathWriteCount "second run must not write again"
        $neovideEntries = @($script:userPathStore -split ";" | Where-Object { $_ -ieq "C:\Program Files\Neovide" })
        Assert-Equal 1 $neovideEntries.Count "exactly one Neovide entry"
        Assert-True ($script:userPathStore -like "C:\Existing\Bin*") "unrelated entry still present"
    }

    # --- 7. already on PATH: preserved untouched ---------------------------
    Invoke-Test -Name "Neovide already on PATH is preserved untouched" -Body {
        Reset-TestState
        $script:userPathStore = "C:\Existing\Bin;C:\Program Files\Neovide"

        $null = Invoke-BootstrapWindows `
            -Packages @("Neovide.Neovide") `
            -Executor $script:runner `
            -SkipFont `
            -Notify $script:notify `
            -TestCommand $script:testCommand `
            -TestPath $script:testPath `
            -ReadUserPath $script:readUserPath `
            -WriteUserPath $script:writeUserPath `
            -NvimVersionOutput "NVIM v0.12.4"

        Assert-Equal 0 $script:pathWriteCount "no PATH write when already resolvable"
        Assert-Equal "C:\Existing\Bin;C:\Program Files\Neovide" $script:userPathStore "user PATH unchanged"
    }

    # --- 8. missing executable: throws, no false success, no PATH write ----
    Invoke-Test -Name "missing Neovide executable throws without PATH write" -Body {
        Reset-TestState
        $script:neovideExePresent = $false
        $script:userPathStore = "C:\Existing\Bin"

        Assert-Throws {
            Invoke-BootstrapWindows `
                -Packages @("Neovide.Neovide") `
                -Executor $script:runner `
                -SkipFont `
                -Notify $script:notify `
                -TestCommand $script:testCommand `
                -TestPath $script:testPath `
                -ReadUserPath $script:readUserPath `
                -WriteUserPath $script:writeUserPath `
                -NvimVersionOutput "NVIM v0.12.4"
        } -Message "missing Neovide executable must fail the bootstrap" `
          -ExpectedFragments @("Neovide", "neovide.exe")

        Assert-Equal 0 $script:pathWriteCount "no PATH write when executable is missing"
        Assert-Equal "C:\Existing\Bin" $script:userPathStore "user PATH unchanged"
        Assert-True ($script:notified.Count -eq 0) "no success message when Neovide is missing"
    }

    # --- 9. Neovim 0.11 rejected, 0.12 accepted ----------------------------
    Invoke-Test -Name "Neovim 0.11 rejected with detected and required versions" -Body {
        try {
            $null = Assert-NeovimMinimumVersion -VersionOutput "NVIM v0.11.4" -MinimumVersion "0.12.0"
            throw "expected 0.11 to be rejected"
        } catch {
            if ($_.Exception.Message -notlike "*0.11.4*") {
                throw "error must report the detected version; got: $($_.Exception.Message)"
            }
            if ($_.Exception.Message -notlike "*0.12.0*") {
                throw "error must report the required version; got: $($_.Exception.Message)"
            }
        }
    }

    Invoke-Test -Name "Neovim 0.12 accepted" -Body {
        $detected = Assert-NeovimMinimumVersion -VersionOutput "NVIM v0.12.4" -MinimumVersion "0.12.0"
        Assert-Equal "v0.12.4" $detected
        $devDetected = Assert-NeovimMinimumVersion -VersionOutput "NVIM v0.12.0-dev-1234+gabc1234" -MinimumVersion "0.12.0"
        Assert-Equal "v0.12.0" $devDetected
        $newerDetected = Assert-NeovimMinimumVersion -VersionOutput "NVIM v0.13.1" -MinimumVersion "0.12.0"
        Assert-Equal "v0.13.1" $newerDetected
    }

    # --- 11. Add-PathEntryString: idempotent, order-preserving, dedupes ----
    Invoke-Test -Name "PATH entry helper is idempotent and preserves unrelated entries" -Body {
        $result = Add-PathEntryString -PathValue "C:\A;C:\B;" -Entry "C:\Program Files\Neovide"
        Assert-Equal "C:\A;C:\B;C:\Program Files\Neovide" $result "append drops empty segments"
        $again = Add-PathEntryString -PathValue $result -Entry "C:\Program Files\Neovide"
        Assert-True ($again -ceq $result) "repeated call must be a no-op"
        $mixed = Add-PathEntryString -PathValue "c:\program files\neovide;C:\A" -Entry "C:\Program Files\Neovide"
        Assert-True ($mixed -ceq "c:\program files\neovide;C:\A") "existing entry (any case) must be left untouched"
    }

    # --- 12. Read-VersionsFile: tolerant parser over the shared versions.sh --
    Invoke-Test -Name "versions file parser tolerates CRLF, comments, and blank lines" -Body {
        $tmp = [IO.Path]::GetTempFileName()
        Set-Content -LiteralPath $tmp -Value "# pinned assets`r`n`r`nNVIM_VERSION=`"0.12.4`"`r`nOXPROTO_SHA256_ZIP=`"abc123`"" -NoNewline
        try {
            $v = Read-VersionsFile -Path $tmp
            Assert-Equal "0.12.4" $v.NVIM_VERSION "NVIM_VERSION must parse through CRLF"
            Assert-Equal "abc123" $v.OXPROTO_SHA256_ZIP "OXPROTO_SHA256_ZIP must parse"
            Assert-Equal 2 $v.Count "parser must yield exactly the declared keys"
        } finally {
            Remove-Item -LiteralPath $tmp -Force
        }
    }

    Invoke-Test -Name "malformed versions line fails loudly" -Body {
        $tmp = [IO.Path]::GetTempFileName()
        Set-Content -LiteralPath $tmp -Value "NVIM_VERSION=0.12.4" -NoNewline
        try {
            Assert-Throws -Action { $null = Read-VersionsFile -Path $tmp } `
                -Message "unquoted value must be rejected" -ExpectedFragments @("malformed")
        } finally {
            Remove-Item -LiteralPath $tmp -Force
        }
    }

    Invoke-Test -Name "shared versions file provides the Windows font version and hash" -Body {
        $v = Read-VersionsFile -Path (Join-Path $script:BootstrapDir "versions.sh")
        Assert-True ($v.NERD_FONTS_VERSION -match '^\d+\.\d+\.\d+$') "NERD_FONTS_VERSION must be pinned"
        Assert-True ($v.OXPROTO_SHA256_ZIP.Length -eq 64) "OXPROTO_SHA256_ZIP must be a SHA-256"
        Assert-True ($v.OXPROTO_SHA256_XZ.Length -eq 64) "OXPROTO_SHA256_XZ must be a SHA-256"
        Assert-True ($v.OXPROTO_SHA256_XZ -ne $v.OXPROTO_SHA256_ZIP) "zip/xz archives must have distinct hashes"
    }
} finally {
    $env:Path = $script:originalProcessPath
}

Write-Host ""
Write-Host "PASS: $($script:passCount)  FAIL: $($script:failCount)"
if ($script:failCount -gt 0) {
    exit 1
}
