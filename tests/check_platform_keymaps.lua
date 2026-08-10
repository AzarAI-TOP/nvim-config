local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

if vim.fn.has("win32") == 1 then
    check(vim.fn.maparg("<leader>W", "n") == "", "Windows must not register the sudo-save mapping")
end

local config_mapping = vim.fn.maparg("<leader>fc", "n", false, true)
check(type(config_mapping.callback) == "function", "config picker must use a callback with a runtime stdpath")

if type(config_mapping.callback) == "function" then
    local fzf = require("fzf-lua")
    local original_files = fzf.files
    local captured
    fzf.files = function(opts) captured = opts end
    local ok, err = pcall(config_mapping.callback)
    fzf.files = original_files
    check(ok, "config picker callback failed: " .. tostring(err))
    check(captured and captured.cwd == vim.fn.stdpath("config"), "config picker cwd must equal stdpath('config')")
end

if #failures > 0 then
    io.stderr:write("PLATFORM_KEYMAP_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("PLATFORM_KEYMAP_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
