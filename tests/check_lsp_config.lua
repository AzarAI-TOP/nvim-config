local servers = require("config.tools").lsp_servers

local ok, err = pcall(function()
    for _, server in ipairs(servers) do
        local config = vim.lsp.config[server]
        assert(config, server .. ": config is missing")
        local cmd_type = type(config.cmd)
        local has_cmd = cmd_type == "function" or (cmd_type == "table" and config.cmd[1])
        assert(has_cmd, server .. ": cmd is missing")
        assert(type(config.filetypes) == "table" and config.filetypes[1], server .. ": filetypes are missing")
    end
end)

if not ok then
    io.stderr:write("LSP_CONFIG_CHECK_FAILED: " .. tostring(err) .. "\n")
    io.stderr:flush()
    vim.cmd("cquit 1")
end

io.stdout:write("LSP_CONFIG_CHECK_OK servers=" .. #servers .. "\n")
io.stdout:flush()
if not vim.g.config_test_runner then vim.cmd("qa") end
