# Bootstraps Windows system-level dependencies. Run in PowerShell.
# Mason installs the LSP servers and portable formatters.
#
# When dot-sourced, the script only defines functions and state, so it can be
# loaded safely in an isolated environment; Invoke-BootstrapWindows only runs
# when the script is invoked directly.
#
# Behavior guarantees:
#  - Every key native command (winget, rustup, nvim) runs through
#    Invoke-NativeChecked and fails immediately on unacceptable exit codes.
#  - One package failure aborts the bootstrap: remaining packages, the Mason
#    step, and the final success message are all skipped.
#  - The Neovide PATH repair runs after installation and process-PATH refresh,
#    so a clean first run actually fixes it.
#  - Neovim 0.12.0 or newer is required after installation.

$ErrorActionPreference = "Stop"

$script:DefaultPackages = @(
    "Git.Git",
    "Neovim.Neovim",
    "Neovide.Neovide",
    "BurntSushi.ripgrep.MSVC",
    "junegunn.fzf",
    "JesseDuffield.lazygit",
    "OpenJS.NodeJS.LTS",
    "Python.Python.3.13",
    "GoLang.Go",
    "Rustlang.Rustup",
    "Microsoft.OpenJDK.21",
    "LLVM.LLVM",
    "7zip.7zip"
)

# Documented winget install exit codes: for an idempotent bootstrap they still
# mean "the package is already in place".
# Source: microsoft/winget-cli, src/AppInstallerSharedLib/Public/AppInstallerErrors.h
#   0x8A15010D APPINSTALLER_CLI_ERROR_INSTALL_ALREADY_INSTALLED
#   0x8A15010E APPINSTALLER_CLI_ERROR_INSTALL_DOWNGRADE
#              (a newer version is already installed)
# All other exit codes fail the bootstrap. Hex values are converted through a
# bit pattern so the signed Int32 result is identical on PowerShell 5.1 and 7
# (5.1 rejects a direct narrowing [int] conversion).
function ConvertTo-Int32FromHex32 {
    param([Parameter(Mandatory)][string]$Hex)
    return [BitConverter]::ToInt32(
        [BitConverter]::GetBytes([uint32]::Parse($Hex, [System.Globalization.NumberStyles]::HexNumber)),
        0)
}

$script:BootstrapDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Read-VersionsFile {
    # Parses the KEY="VALUE" versions file (scripts/versions.sh) without
    # executing it. Tolerates CRLF line endings, blank lines, and # comments.
    # Unknown or malformed lines are treated as errors so version drift can't
    # fail silently.
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Versions file '$Path' not found"
    }
    $result = @{}
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        if ($trimmed -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]*)"$') {
            $result[$Matches[1]] = $Matches[2]
        } else {
            throw "Malformed line in versions file: '$line'"
        }
    }
    return $result
}

function Get-NormalizedHotkey {
    # WScript.Shell serializes .lnk hotkeys with its own modifier-key order
    # (e.g. writing "Ctrl+Alt+N" reads back "Alt+Ctrl+N");
    # so compare normalized key sets instead of strings.
    param([AllowEmptyString()][string]$Value)
    return (@($Value.ToLowerInvariant() -split "\+" | Where-Object { $_ } | Sort-Object) -join "+")
}

$script:DefaultShortcutFactory = {
    # Creates a shortcut; skips when a shortcut with the requested hotkey
    # already exists (returns $null). Uses the WScript.Shell COM object.
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
    # Creates the documented Ctrl+Alt+N Start Menu Neovide launcher.
    # The COM factory is injectable, so the logic tests never touch the real
    # Start Menu or registry.
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
        throw "Neovide executable not found at '$TargetPath'; cannot create the Start Menu shortcut."
    }
    if ($null -eq $ShortcutFactory) {
        $ShortcutFactory = $script:DefaultShortcutFactory
    }
    if (-not $PSCmdlet.ShouldProcess($ShortcutPath, "Create Neovide shortcut with hotkey $Hotkey")) {
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
    # Runs a native command (or an injected fake executor), preserves its
    # output, and throws an exception with command/context info when the exit
    # code is unacceptable. $ErrorActionPreference = "Stop" alone does not
    # fail on non-zero native exit codes.
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
    # Pure helper: returns a PATH string containing $Entry exactly once.
    # Unrelated entries keep their original order; only appending drops empty
    # segments. Existing entries (case-insensitive) are kept as-is; repeated
    # calls are no-ops.
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
    # entries. I/O is injectable, so tests never touch the real user PATH.
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
    # Neovide installs to $NeovideDirectory, but the winget package does not
    # add it to PATH. Adds the directory to the user PATH exactly once and
    # refreshes the process PATH; then throws if the executable is missing or
    # still unresolvable (no fake success).
    param(
        [string]$NeovideDirectory = "C:\Program Files\Neovide",
        [scriptblock]$TestPath = { param($path) Test-Path -LiteralPath $path },
        [scriptblock]$TestCommand = { param($name) Get-Command $name -ErrorAction SilentlyContinue },
        [scriptblock]$ReadUserPath = { [Environment]::GetEnvironmentVariable("Path", "User") },
        [scriptblock]$WriteUserPath = { param($value) [Environment]::SetEnvironmentVariable("Path", $value, "User") }
    )
    $neovideExe = Join-Path $NeovideDirectory "neovide.exe"
    if (-not (& $TestPath $neovideExe)) {
        throw "Neovide executable not found at '$neovideExe' after winget install. Neovide is not installed correctly; please re-run the bootstrap."
    }
    if (& $TestCommand "neovide") {
        return
    }
    $null = Add-UserPathEntry -Directory $NeovideDirectory -ReadPath $ReadUserPath -WritePath $WriteUserPath
    $env:Path = Add-PathEntryString -PathValue $env:Path -Entry $NeovideDirectory
    if (-not (& $TestCommand "neovide")) {
        throw "Neovide is installed, but still cannot be resolved after updating PATH. Open a new PowerShell window and re-run the bootstrap."
    }
}

function Assert-NeovimMinimumVersion {
    # Throws with the detected and required versions when the installed Neovim
    # is below $MinimumVersion; returns the detected version on success.
    param(
        [Parameter(Mandatory)][string]$VersionOutput,
        [string]$MinimumVersion = "0.12.0"
    )
    if ($VersionOutput -notmatch "NVIM v(?<major>[0-9]+)\.(?<minor>[0-9]+)\.(?<patch>[0-9]+)") {
        $firstLine = ($VersionOutput -split "`r?`n" | Where-Object { $_ } | Select-Object -First 1)
        throw "Could not determine the Neovim version from the output ('$firstLine'); cannot verify the $MinimumVersion minimum requirement."
    }
    $detectedVersion = "v$($Matches['major']).$($Matches['minor']).$($Matches['patch'])"
    $minimumParts = $MinimumVersion -split "\."
    $detectedMajor = [int]$Matches['major']
    $detectedMinor = [int]$Matches['minor']
    $minimumMajor = [int]$minimumParts[0]
    $minimumMinor = [int]$minimumParts[1]
    if ($detectedMajor -lt $minimumMajor -or
        ($detectedMajor -eq $minimumMajor -and $detectedMinor -lt $minimumMinor)) {
        throw "Detected Neovim $detectedVersion, but $MinimumVersion or newer is required. Update Neovim and re-run the bootstrap."
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
        throw "winget is required. Install or update Microsoft App Installer first."
    }

    foreach ($package in $Packages) {
        Invoke-NativeChecked -Command "winget" `
            -Arguments @("install", "--id", $package, "--exact", "--accept-package-agreements", "--accept-source-agreements") `
            -AcceptableExitCodes $script:WingetInstallAcceptableExitCodes `
            -Context "winget package '$package'" `
            -Executor $Executor
    }

    # Refresh the current process after installers update the registry env.
    $env:Path = @(
        [Environment]::GetEnvironmentVariable("Path", "Machine"),
        [Environment]::GetEnvironmentVariable("Path", "User")
    ) -join ";"

    # Resolve the Neovide install directory instead of hardcoding it: PATH
    # first (already-repaired environments), then winget's two known targets
    # (machine-wide Program Files, per-user LOCALAPPDATA\Programs). Falls back
    # to Program Files so a missing install still surfaces Repair-NeovidePath's
    # explicit error.
    $neovideCommand = & $TestCommand "neovide"
    $neovideCandidates = @()
    if ($neovideCommand) { $neovideCandidates += (Split-Path -Parent $neovideCommand.Source) }
    $neovideCandidates += @(
        (Join-Path $env:ProgramFiles "Neovide"),
        (Join-Path $env:LOCALAPPDATA "Programs\Neovide")
    )
    $neovideDirectory = $neovideCandidates |
        Where-Object { & $TestPath (Join-Path $_ "neovide.exe") } |
        Select-Object -First 1
    if (-not $neovideDirectory) {
        $neovideDirectory = Join-Path $env:ProgramFiles "Neovide"
    }

    # The Neovide PATH repair must run after installation and the PATH refresh,
    # so a clean first run actually fixes it.
    Repair-NeovidePath -NeovideDirectory $neovideDirectory `
        -TestPath $TestPath -TestCommand $TestCommand `
        -ReadUserPath $ReadUserPath -WriteUserPath $WriteUserPath

    # Start Menu shortcut with the documented Ctrl+Alt+N hotkey. Idempotent:
    # the factory skips creation when a shortcut with that hotkey exists.
    $null = New-NeovideShortcut `
        -TargetPath (Join-Path $neovideDirectory "neovide.exe") `
        -ShortcutFactory $ShortcutFactory `
        -TestPath $TestPath

    # Some winget versions create the portable fzf package but miss its PATH
    # directory. Fix it idempotently for the current process and future shells.
    $fzfDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\junegunn.fzf_Microsoft.Winget.Source_8wekyb3d8bbwe"
    if ((& $TestPath (Join-Path $fzfDirectory "fzf.exe")) -and -not (& $TestCommand "fzf")) {
        $null = Add-UserPathEntry -Directory $fzfDirectory -ReadPath $ReadUserPath -WritePath $WriteUserPath
        $env:Path = Add-PathEntryString -PathValue $env:Path -Entry $fzfDirectory
    }

    # Same portable-package PATH repair for lazygit (toggleterm <leader>tg).
    $lazygitDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\JesseDuffield.lazygit_Microsoft.Winget.Source_8wekyb3d8bbwe"
    if ((& $TestPath (Join-Path $lazygitDirectory "lazygit.exe")) -and -not (& $TestCommand "lazygit")) {
        $null = Add-UserPathEntry -Directory $lazygitDirectory -ReadPath $ReadUserPath -WritePath $WriteUserPath
        $env:Path = Add-PathEntryString -PathValue $env:Path -Entry $lazygitDirectory
    }

    # ipython powers the <leader>tp REPL inside toggleterm terminals; install
    # it into the active Python so `ipython` resolves from nvim's terminals.
    $pythonCommand = & $TestCommand "python"
    if ($pythonCommand) {
        Invoke-NativeChecked -Command $pythonCommand.Source `
            -Arguments @("-m", "pip", "install", "--quiet", "ipython") `
            -Context "pip install ipython" `
            -Executor $Executor
    }

    if (-not $SkipFont) {
        # Install the per-user Nerd Font that Neovide renders with.
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
        throw "nvim is still not on PATH. Open a new PowerShell window and re-run this script."
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

    & $Notify "Windows bootstrap complete. Run :checkhealth in Neovim to verify the environment."
}

if ($MyInvocation.InvocationName -ne ".") {
    Invoke-BootstrapWindows
}
