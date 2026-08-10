local tools = require("config.tools")
local failures = {}

local function validate_unique_nonempty(values, label)
    local seen = {}
    for _, value in ipairs(values) do
        if type(value) ~= "string" or value == "" then
            table.insert(failures, label .. " contains an invalid name")
        elseif seen[value] then
            table.insert(failures, label .. " contains duplicate: " .. value)
        else
            seen[value] = true
        end
    end
end

validate_unique_nonempty(tools.lsp_servers, "lsp_servers")
validate_unique_nonempty(tools.mason_formatters, "mason_formatters")
validate_unique_nonempty(tools.mason_packages, "mason_packages")
validate_unique_nonempty(tools.system_tools, "system_tools")

if #tools.mason_packages ~= #tools.lsp_servers + #tools.mason_formatters then
    table.insert(failures, "mason_packages must contain every LSP server and formatter exactly once")
end

if #failures > 0 then
    io.stderr:write("TOOL_INVENTORY_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write(
    ("TOOL_INVENTORY_CHECK_OK lsp=%d formatters=%d system=%d\n"):format(
        #tools.lsp_servers,
        #tools.mason_formatters,
        #tools.system_tools
    )
)
if not vim.g.config_test_runner then vim.cmd("qa") end
