-- Integration check for a fully bootstrapped environment.
-- Run with an actual Lua file open after Mason installation.

assert(vim.fn.executable("stylua") == 1, "stylua missing")
assert(
    vim.wait(15000, function() return #vim.lsp.get_clients({ bufnr = 0, name = "lua_ls" }) > 0 end, 100),
    "lua_ls did not attach"
)

local scratch = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(scratch)
vim.bo[scratch].filetype = "lua"
vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { "local   value={a=1,b=2}" })

local finished, format_error, did_edit = false, nil, nil
require("conform").format({ bufnr = scratch, async = true }, function(err, edited)
    format_error, did_edit, finished = err, edited, true
end)
assert(vim.wait(10000, function() return finished end, 50), "Conform callback timed out")
assert(format_error == nil, "Conform failed: " .. tostring(format_error))
assert(did_edit == true, "Conform did not edit malformed Lua")
local formatted = table.concat(vim.api.nvim_buf_get_lines(scratch, 0, -1, false), "\n")
assert(formatted:find("local value =", 1, true) ~= nil, "StyLua output was not applied")

print("FIRST_BOOT_RUNTIME_OK lsp=lua_ls formatter=stylua did_edit=true")
vim.cmd("qall!")
