-- 测试运行器：必须通过 scripts/test-config.sh 或 test-config.ps1 运行。
-- 以 NVIM_CONFIG_TEST=1 启动，逐个执行 tests/ 下的检查文件。

if vim.env.NVIM_CONFIG_TEST ~= "1" then
    error("请通过 scripts/test-config.sh 或 scripts/test-config.ps1 运行测试")
end

vim.g.config_test_runner = true

local tests = {
    "check_startup.lua",
    "check_platform.lua",
    "check_editorconfig.lua",
    "check_completion.lua",
    "check_mini_clue.lua",
    "check_formatters.lua",
    "check_tool_inventory.lua",
    "check_pack_commands.lua",
    "check_plugin_lifecycle.lua",
    "check_reload.lua",
}

local test_dir = vim.fs.joinpath(vim.fn.getcwd(), "tests")
local failed = 0
for _, test in ipairs(tests) do
    local ok, err = pcall(dofile, vim.fs.joinpath(test_dir, test))
    if not ok then
        failed = failed + 1
        io.stderr:write("TEST_FILE_ERROR " .. test .. ": " .. tostring(err) .. "\n")
    end
end

if failed > 0 then
    io.stderr:write(("CONFIG_TEST_SUITE_FAILED files=%d\n"):format(failed))
    io.stderr:flush()
    vim.cmd("cquit 1")
    return
end

io.stdout:write("CONFIG_TEST_SUITE_OK tests=" .. #tests .. "\n")
io.stdout:flush()
vim.cmd("qa")
