if vim.env.NVIM_CONFIG_TEST ~= "1" then error("Run tests through scripts/test-config.sh or scripts/test-config.ps1") end

vim.g.config_test_runner = true

local tests = {
    "check_startup.lua",
    "check_platform.lua",
    "check_completion.lua",
    "check_mini_clue.lua",
    "check_formatters.lua",
    "check_tool_inventory.lua",
    "check_pack_commands.lua",
    "check_plugin_lifecycle.lua",
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
