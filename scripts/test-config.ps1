# Run the config suite from a disposable XDG environment.

$ErrorActionPreference = "Stop"

# The suite runs in test mode (NVIM_CONFIG_TEST=1): Mason setup stays
# synchronous but the automatic install check is disabled, so headless runs
# never hit the network.
Remove-Item Env:NVIM_BOOTSTRAP -ErrorAction SilentlyContinue

$repoRoot = Split-Path -Parent $PSScriptRoot
$testId = [guid]::NewGuid().ToString("N").Substring(0, 8)
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("nv-" + $testId)
$configRoot = Join-Path $tempRoot "c\nvim"

try {
    New-Item -ItemType Directory -Force -Path $configRoot | Out-Null
    Get-ChildItem -Path $repoRoot -Force | Where-Object { $_.Name -ne ".git" } | ForEach-Object {
        Copy-Item $_.FullName -Destination $configRoot -Recurse -Force
    }

    $env:XDG_CONFIG_HOME = Join-Path $tempRoot "c"
    # TEST_DATA_HOME reuses a persistent plugin install (vim.pack downloads
    # all 21 plugins on a fresh data dir, which dominates suite runtime).
    # The suite never installs Mason packages, so a shared data dir is safe.
    if ($env:TEST_DATA_HOME) {
        New-Item -ItemType Directory -Force -Path $env:TEST_DATA_HOME | Out-Null
        $env:XDG_DATA_HOME = $env:TEST_DATA_HOME
    } else {
        $env:XDG_DATA_HOME = Join-Path $tempRoot "d"
    }
    $env:XDG_STATE_HOME = Join-Path $tempRoot "s"
    $env:XDG_CACHE_HOME = Join-Path $tempRoot "x"
    $env:NVIM_CONFIG_TEST = "1"
    $env:GIT_CONFIG_COUNT = "1"
    $env:GIT_CONFIG_KEY_0 = "core.longpaths"
    $env:GIT_CONFIG_VALUE_0 = "true"

    Push-Location $configRoot
    try {
        & nvim --headless "+lua dofile(vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'run.lua'))"
        if ($LASTEXITCODE -ne 0) { throw "Config tests failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
