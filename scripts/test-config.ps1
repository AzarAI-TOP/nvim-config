# 在一次性 XDG 环境中运行配置测试套件。

$ErrorActionPreference = "Stop"

# 套件以测试模式运行（NVIM_CONFIG_TEST=1）：Mason setup 保持同步，
# 但自动安装检查被关闭，headless 运行绝不联网。
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
    # TEST_DATA_HOME 复用持久化的插件安装（全新数据目录会触发
    # vim.pack 下载全部 21 个插件，主导套件耗时）。
    # 套件从不安装 Mason 包，因此共享数据目录是安全的。
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
        $output = & nvim --headless "+lua dofile(vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'run.lua'))" 2>&1
        $output | ForEach-Object { Write-Output $_ }
        if ($LASTEXITCODE -ne 0) { throw "配置测试失败，退出码 $LASTEXITCODE" }
        if (-not ($output -match 'CONFIG_TEST_SUITE_OK')) { throw "配置测试未报告 CONFIG_TEST_SUITE_OK" }
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
