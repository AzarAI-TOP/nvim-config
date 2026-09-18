# Bootstraps the Windows system-level dependencies for this Neovim config.
# Run in PowerShell. Mason installs the LSP servers and portable formatters.
#
# Scoped to this machine's baseline after the Go / Rust / JVM development
# moved to the Ubuntu box: those toolchains are deliberately not installed.
# Git and Node.js stay in the list because the plugin/LSP layer hard-depends
# on them (vim.pack clones via git; the npm-based Mason servers run on node) —
# today they happen to resolve from the agent toolchain on PATH, but a
# from-scratch restore re-establishes them independently. The C compiler the
# tree-sitter parser builds need is NOT installed here: this machine provides
# it through CodeBlocks' MinGW via the ~/.local/bin shims.
#
# Every package installs through winget; the Neovide PATH repair and the
# Ctrl+Alt+N Start Menu launcher are fixed up afterwards, and every installed
# tool is mirrored into PATH for the current process so later steps resolve.
#
# Native exit codes are deliberately not checked (see the equivalent Linux
# script's `set -e` for the one guarantee kept there): if something is missing
# afterwards, re-run the script and read winget's own output.

$ErrorActionPreference = "Stop"

$script:DefaultPackages = @(
    "Git.Git",
    "Neovim.Neovim",
    "Neovide.Neovide",
    "BurntSushi.ripgrep.MSVC",
    "junegunn.fzf",
    "JesseDuffield.lazygit",
    "OpenJS.NodeJS.LTS",
    "Python.Python.3.14"
)

$script:NerdFontsVersion = "3.5.0"

$script:BootstrapDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-NormalizedHotkey {
    # WScript.Shell serializes .lnk hotkeys with its own modifier-key order
    # (e.g. writing "Ctrl+Alt+N" reads back "Alt+Ctrl+N"), so compare
    # normalized key sets instead of strings.
    param([AllowEmptyString()][string]$Value)
    return (@($Value.ToLowerInvariant() -split "\+" | Where-Object { $_ } | Sort-Object) -join "+")
}

function New-NeovideShortcut {
    # Creates the documented Ctrl+Alt+N Start Menu Neovide launcher. Idempotent:
    # skips creation when a shortcut with that hotkey already exists.
    param(
        [string]$TargetPath = "C:\Program Files\Neovide\neovide.exe",
        [string]$Hotkey = "Ctrl+Alt+N"
    )
    $lnkPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Neovide.lnk"
    $shell = New-Object -ComObject WScript.Shell
    if (Test-Path -LiteralPath $lnkPath) {
        $existing = $shell.CreateShortcut($lnkPath)
        if ((Get-NormalizedHotkey $existing.Hotkey) -eq (Get-NormalizedHotkey $Hotkey)) {
            return
        }
    }
    $shortcut = $shell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Hotkey = $Hotkey
    $shortcut.Save()
}

function Add-PathEntryString {
    # Pure helper: returns a PATH string containing $Entry exactly once.
    # Unrelated entries keep their original order; an existing entry
    # (case-insensitive) is returned unchanged, so repeated calls are no-ops.
    param(
        [Parameter(Mandatory)][string]$PathValue,
        [Parameter(Mandatory)][string]$Entry
    )
    $cleaned = @()
    foreach ($segment in @($PathValue -split ";" | Where-Object { $_ })) {
        if ([string]::Equals($segment, $Entry, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $PathValue
        }
        $cleaned += $segment
    }
    $cleaned += $Entry
    return ($cleaned -join ";")
}

function Add-UserPathEntry {
    # Adds $Directory to the user PATH exactly once, preserving unrelated entries.
    param([Parameter(Mandatory)][string]$Directory)
    $current = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($null -eq $current) { $current = "" }
    $updated = Add-PathEntryString -PathValue $current -Entry $Directory
    if ($updated -ne $current) {
        [Environment]::SetEnvironmentVariable("Path", $updated, "User")
    }
}

function Repair-NeovidePath {
    # Neovide installs to $NeovideDirectory, but the winget package does not add
    # it to PATH. Adds the directory to the user PATH (future shells) and to the
    # process PATH (this run).
    param([string]$NeovideDirectory = "C:\Program Files\Neovide")
    if (Get-Command neovide -ErrorAction SilentlyContinue) { return }
    Add-UserPathEntry -Directory $NeovideDirectory
    $env:Path = Add-PathEntryString -PathValue $env:Path -Entry $NeovideDirectory
}

function Invoke-BootstrapWindows {
    param([string[]]$Packages = $script:DefaultPackages)

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget is required. Install or update Microsoft App Installer first."
    }

    foreach ($package in $Packages) {
        winget install --id $package --exact --accept-package-agreements --accept-source-agreements
    }

    # Refresh the current process after installers update the registry env.
    $env:Path = @(
        [Environment]::GetEnvironmentVariable("Path", "Machine"),
        [Environment]::GetEnvironmentVariable("Path", "User")
    ) -join ";"

    # Resolve the Neovide install directory instead of hardcoding it: PATH first
    # (already-repaired environments), then winget's two known targets
    # (machine-wide Program Files, per-user LOCALAPPDATA\Programs).
    $neovideCommand = Get-Command neovide -ErrorAction SilentlyContinue
    $neovideCandidates = @()
    if ($neovideCommand) { $neovideCandidates += (Split-Path -Parent $neovideCommand.Source) }
    $neovideCandidates += @(
        (Join-Path $env:ProgramFiles "Neovide"),
        (Join-Path $env:LOCALAPPDATA "Programs\Neovide")
    )
    $neovideDirectory = $neovideCandidates |
        Where-Object { Test-Path -LiteralPath (Join-Path $_ "neovide.exe") } |
        Select-Object -First 1
    if (-not $neovideDirectory) {
        $neovideDirectory = Join-Path $env:ProgramFiles "Neovide"
    }

    # Both run after the install and the PATH refresh, so a clean first run
    # actually fixes them.
    Repair-NeovidePath -NeovideDirectory $neovideDirectory
    New-NeovideShortcut -TargetPath (Join-Path $neovideDirectory "neovide.exe")

    # Some winget versions create a portable package but miss its PATH
    # directory. Fix it for the current process and for future shells.
    $portableTools = @(
        @{ Exe = "fzf"; Directory = (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\junegunn.fzf_Microsoft.Winget.Source_8wekyb3d8bbwe") },
        @{ Exe = "lazygit"; Directory = (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\JesseDuffield.lazygit_Microsoft.Winget.Source_8wekyb3d8bbwe") }
    )
    foreach ($tool in $portableTools) {
        if ((Test-Path -LiteralPath $tool.Directory) -and -not (Get-Command $tool.Exe -ErrorAction SilentlyContinue)) {
            Add-UserPathEntry -Directory $tool.Directory
            $env:Path = Add-PathEntryString -PathValue $env:Path -Entry $tool.Directory
        }
    }

    # ipython powers the <leader>tp REPL inside toggleterm terminals; install it
    # into the active Python so `ipython` resolves from nvim's terminals.
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        & $python.Source -m pip install --quiet ipython
    }

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
            Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/download/v$($script:NerdFontsVersion)/0xProto.zip" -OutFile $fontArchive
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

    # Every plugin loads at startup, so :Mason* resolves without the
    # NVIM_BOOTSTRAP env var the deferred loader used to require.
    nvim --headless "+MasonToolsInstallSync" "+qa!"

    Write-Output "Windows bootstrap complete. Run :checkhealth in Neovim to verify the environment."
}

Invoke-BootstrapWindows
