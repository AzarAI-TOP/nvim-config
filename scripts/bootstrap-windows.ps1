# Bootstrap system-level dependencies for Windows.
# Run from PowerShell. Mason installs LSP servers and portable formatters.
#
# The script only defines functions and state when dot-sourced, so
# scripts/test-bootstrap-windows.ps1 can load it safely with injected fakes
# that never touch real installers, the registry, or the user PATH.
# It executes Invoke-BootstrapWindows only when invoked directly.
#
# Behavior guarantees:
#  - Every critical native command (winget, rustup, nvim) is executed through
#    Invoke-NativeChecked, which fails fast on an unacceptable exit code.
#  - One failed package aborts the bootstrap: later packages, the Mason step
#    and the final success message are all skipped.
#  - The Neovide PATH repair runs AFTER installation and the process PATH
#    refresh, so a clean first run actually repairs it.
#  - Neovim 0.12.0 or newer is required after installation.

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

# Documented winget install exit codes that still mean "the package is
# present" for an idempotent bootstrap. Source: microsoft/winget-cli,
# src/AppInstallerSharedLib/Public/AppInstallerErrors.h
#   0x8A15010D APPINSTALLER_CLI_ERROR_INSTALL_ALREADY_INSTALLED
#   0x8A15010E APPINSTALLER_CLI_ERROR_INSTALL_DOWNGRADE
#              (a newer version is already installed)
# Everything else fails the bootstrap. The hex values are converted through
# their bit pattern so the signed Int32 result is identical on PowerShell 5.1
# and 7 (5.1 rejects a direct narrowing [int] cast).
function ConvertTo-Int32FromHex32 {
    param([Parameter(Mandatory)][string]$Hex)
    return [BitConverter]::ToInt32(
        [BitConverter]::GetBytes([uint32]::Parse($Hex, [System.Globalization.NumberStyles]::HexNumber)),
        0)
}

$script:BootstrapDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Read-VersionsFile {
    # Parses a KEY="VALUE" versions file (scripts/versions.sh) WITHOUT
    # executing it. Tolerates CRLF line endings, blank lines, and # comments.
    # Unknown or malformed lines are an error so a drift never fails silently.
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "versions file not found at '$Path'"
    }
    $result = @{}
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        if ($trimmed -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]*)"$') {
            $result[$Matches[1]] = $Matches[2]
        } else {
            throw "malformed versions line: '$line'"
        }
    }
    return $result
}

$script:WingetInstallAcceptableExitCodes = @(
    0,
    (ConvertTo-Int32FromHex32 "8A15010D"),
    (ConvertTo-Int32FromHex32 "8A15010E")
)

function Invoke-NativeChecked {
    # Runs a native command (or an injected fake executor), preserves its
    # output, and throws with actionable command/context information when the
    # exit code is not acceptable. $ErrorActionPreference = "Stop" alone does
    # not fail on a native command's non-zero exit code.
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
        $contextText = if ($Context) { " ($Context)" } else { "" }
        throw "Command '$Command$argumentsText' failed with exit code $exitCode.$contextText"
    }
}

function Add-PathEntryString {
    # Pure helper: returns a PATH string that contains $Entry exactly once.
    # Unrelated entries are preserved in order; empty segments are dropped
    # only when an entry is appended. Existing entries (any case) are left
    # untouched, which makes repeated calls a no-op.
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
    # Adds $Directory to the user PATH exactly once, preserving unrelated
    # entries. I/O is injectable so tests never touch the real user PATH.
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
    # Neovide installs to $NeovideDirectory but the winget package does not
    # add it to PATH. Adds it to the user PATH exactly once, refreshes the
    # process PATH, and throws if the executable is missing or still not
    # resolvable afterwards (no false success).
    param(
        [string]$NeovideDirectory = "C:\Program Files\Neovide",
        [scriptblock]$TestPath = { param($path) Test-Path -LiteralPath $path },
        [scriptblock]$TestCommand = { param($name) Get-Command $name -ErrorAction SilentlyContinue },
        [scriptblock]$ReadUserPath = { [Environment]::GetEnvironmentVariable("Path", "User") },
        [scriptblock]$WriteUserPath = { param($value) [Environment]::SetEnvironmentVariable("Path", $value, "User") }
    )
    $neovideExe = Join-Path $NeovideDirectory "neovide.exe"
    if (-not (& $TestPath $neovideExe)) {
        throw "Neovide executable not found at '$neovideExe' after winget install. Neovide was not installed correctly; rerun the bootstrap."
    }
    if (& $TestCommand "neovide") {
        return
    }
    $null = Add-UserPathEntry -Directory $NeovideDirectory -ReadPath $ReadUserPath -WritePath $WriteUserPath
    $env:Path = Add-PathEntryString -PathValue $env:Path -Entry $NeovideDirectory
    if (-not (& $TestCommand "neovide")) {
        throw "Neovide is installed but still not resolvable after updating PATH. Open a new PowerShell window and rerun the bootstrap."
    }
}

function Assert-NeovimMinimumVersion {
    # Throws with detected and required versions when the installed Neovim is
    # older than $MinimumVersion. Returns the detected version on success.
    param(
        [Parameter(Mandatory)][string]$VersionOutput,
        [string]$MinimumVersion = "0.12.0"
    )
    if ($VersionOutput -notmatch "NVIM v(?<major>[0-9]+)\.(?<minor>[0-9]+)\.(?<patch>[0-9]+)") {
        $firstLine = ($VersionOutput -split "`r?`n" | Where-Object { $_ } | Select-Object -First 1)
        throw "Could not determine the Neovim version from its output ('$firstLine'); cannot verify the $MinimumVersion minimum."
    }
    $detectedVersion = "v$($Matches['major']).$($Matches['minor']).$($Matches['patch'])"
    $minimumParts = $MinimumVersion -split "\."
    $detectedMajor = [int]$Matches['major']
    $detectedMinor = [int]$Matches['minor']
    $minimumMajor = [int]$minimumParts[0]
    $minimumMinor = [int]$minimumParts[1]
    if ($detectedMajor -lt $minimumMajor -or
        ($detectedMajor -eq $minimumMajor -and $detectedMinor -lt $minimumMinor)) {
        throw "Neovim $detectedVersion detected, but $MinimumVersion or newer is required. Update Neovim and rerun the bootstrap."
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
        [scriptblock]$Notify = { param($message) Write-Host $message },
        [string]$VersionsPath = ""
    )
    if ($null -eq $Packages) { $Packages = $script:DefaultPackages }

    if ($VersionsPath) {
        $script:Versions = Read-VersionsFile -Path $VersionsPath
    } else {
        $script:Versions = Read-VersionsFile -Path (Join-Path $script:BootstrapDir "versions.sh")
    }

    if (-not (& $TestCommand "winget")) {
        throw "winget is required. Install or update Microsoft App Installer first."
    }

    foreach ($package in $Packages) {
        Invoke-NativeChecked -Command "winget" `
            -Arguments @("install", "--id", $package, "--exact", "--accept-package-agreements", "--accept-source-agreements") `
            -AcceptableExitCodes $script:WingetInstallAcceptableExitCodes `
            -Context "winget package '$package'" `
            -Executor $Executor
    }

    # Refresh this process after installers update the registry environment.
    $env:Path = @(
        [Environment]::GetEnvironmentVariable("Path", "Machine"),
        [Environment]::GetEnvironmentVariable("Path", "User")
    ) -join ";"

    # Repair Neovide PATH only AFTER the install and PATH refresh, so a clean
    # first run actually repairs it.
    Repair-NeovidePath -NeovideDirectory "C:\Program Files\Neovide" `
        -TestPath $TestPath -TestCommand $TestCommand `
        -ReadUserPath $ReadUserPath -WriteUserPath $WriteUserPath

    # Some winget versions create the portable fzf package but omit its directory
    # from PATH. Repair it idempotently for both this process and future shells.
    $fzfDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\junegunn.fzf_Microsoft.Winget.Source_8wekyb3d8bbwe"
    if ((& $TestPath (Join-Path $fzfDirectory "fzf.exe")) -and -not (& $TestCommand "fzf")) {
        $null = Add-UserPathEntry -Directory $fzfDirectory -ReadPath $ReadUserPath -WritePath $WriteUserPath
        $env:Path = Add-PathEntryString -PathValue $env:Path -Entry $fzfDirectory
    }

    if (-not $SkipFont) {
        # Install the same per-user Nerd Font used by Neovide on Fedora.
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
                    throw "0xProto archive checksum mismatch"
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
        throw "nvim is not visible in PATH yet. Open a new PowerShell window, then rerun this script."
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

    & $Notify "Windows bootstrap complete. Run :checkhealth nvim_config inside Neovim."
}

if ($MyInvocation.InvocationName -ne ".") {
    Invoke-BootstrapWindows
}
