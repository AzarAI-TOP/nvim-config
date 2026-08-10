if vim.env.NVIM_CONFIG_TEST ~= "1" then error("Run tests through scripts/test-config.sh or scripts/test-config.ps1") end

vim.g.config_test_runner = true

local tests = {
    "check_buffer_keymap.lua",
    "check_format_keymap.lua",
    "check_lsp_config.lua",
    "check_neovide_config.lua",
    "check_platform_detection.lua",
    "check_platform_keymaps.lua",
    "check_tool_inventory.lua",
    "check_windows_shell.lua",
}

local test_dir = vim.fs.joinpath(vim.fn.getcwd(), "tests")
for _, test in ipairs(tests) do
    dofile(vim.fs.joinpath(test_dir, test))
end

io.stdout:write("CONFIG_TEST_SUITE_OK tests=" .. #tests .. "\n")
io.stdout:flush()
vim.cmd("qa")
