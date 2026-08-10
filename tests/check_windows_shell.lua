if vim.fn.has("win32") ~= 1 then
    io.stdout:write("WINDOWS_SHELL_CHECK_SKIPPED\n")
    if not vim.g.config_test_runner then vim.cmd("qa") end
    return
end

local output = vim.fn.system("echo PLATFORM_SHELL_OK")
local shell_error = vim.v.shell_error

if shell_error ~= 0 or not output:find("PLATFORM_SHELL_OK", 1, true) then
    io.stderr:write(
        ("WINDOWS_SHELL_CHECK_FAILED shell=%s shellcmdflag=%s shell_error=%d output=%q\n"):format(
            vim.o.shell,
            vim.o.shellcmdflag,
            shell_error,
            output
        )
    )
    vim.cmd("cquit 1")
end

io.stdout:write("WINDOWS_SHELL_CHECK_OK shell=" .. vim.o.shell .. "\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
