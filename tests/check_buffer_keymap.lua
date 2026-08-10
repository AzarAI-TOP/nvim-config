local semicolon = vim.fn.maparg(";", "n")
local buffer_picker = vim.fn.maparg("<leader>bb", "n")

if semicolon ~= "" or buffer_picker == "" then
    io.stderr:write(("BUFFER_KEYMAP_CHECK_FAILED semicolon=%q leader_bb=%q\n"):format(semicolon, buffer_picker))
    vim.cmd("cquit 1")
end

io.stdout:write("BUFFER_KEYMAP_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
