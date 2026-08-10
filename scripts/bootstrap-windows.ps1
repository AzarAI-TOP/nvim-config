# Bootstrap system-level dependencies for Windows.
# Run from PowerShell. Mason installs LSP servers and portable formatters.

$ErrorActionPreference = "Stop"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget is required. Install or update Microsoft App Installer first."
}

$packages = @(
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

# Neovide installs to C:\Program Files\Neovide but the winget package does not
# add it to PATH. Repair it idempotently so "neovide" works from any shell.
$neovideDir = "C:\Program Files\Neovide"
if ((Test-Path (Join-Path $neovideDir "neovide.exe")) -and -not (Get-Command neovide -ErrorAction SilentlyContinue)) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathParts = @($userPath -split ";" | Where-Object { $_ })
    if ($pathParts -notcontains $neovideDir) {
        [Environment]::SetEnvironmentVariable("Path", (($pathParts + $neovideDir) -join ";") + ";", "User")
    }
    $env:Path += ";$neovideDir"
}

foreach ($package in $packages) {
    winget install --id $package --exact --accept-package-agreements --accept-source-agreements
}

# Refresh this process after installers update the registry environment.
$env:Path = @(
    [Environment]::GetEnvironmentVariable("Path", "Machine"),
    [Environment]::GetEnvironmentVariable("Path", "User")
) -join ";"

# Some winget versions create the portable fzf package but omit its directory
# from PATH. Repair it idempotently for both this process and future shells.
$fzfDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\junegunn.fzf_Microsoft.Winget.Source_8wekyb3d8bbwe"
if ((Test-Path (Join-Path $fzfDirectory "fzf.exe")) -and -not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathParts = @($userPath -split ";" | Where-Object { $_ })
    if ($pathParts -notcontains $fzfDirectory) {
        [Environment]::SetEnvironmentVariable("Path", (($pathParts + $fzfDirectory) -join ";") + ";", "User")
    }
    $env:Path += ";$fzfDirectory"
}

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
        Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/0xProto.zip" -OutFile $fontArchive
        $fontHash = (Get-FileHash -Path $fontArchive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($fontHash -ne "96044c9b041dbe6341a2e8b831259ba8e60f4646e55b721b5f6577505381df1f") {
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

if (Get-Command rustup -ErrorAction SilentlyContinue) {
    & rustup toolchain install stable --profile minimal --component rustfmt
    if ($LASTEXITCODE -ne 0) { throw "Rust toolchain installation failed with exit code $LASTEXITCODE" }
}

if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
    throw "nvim is not visible in PATH yet. Open a new PowerShell window, then rerun this script."
}

$env:NVIM_BOOTSTRAP = "1"
& nvim --headless "+MasonToolsInstallSync" "+lua require('config.mason_verify').assert_all_installed()" "+qa!"
$masonExitCode = $LASTEXITCODE
$env:NVIM_BOOTSTRAP = $null
if ($masonExitCode -ne 0) {
    throw "Mason tool installation failed with exit code $masonExitCode"
}

Write-Host "Windows bootstrap complete. Run :checkhealth nvim_config inside Neovim."
