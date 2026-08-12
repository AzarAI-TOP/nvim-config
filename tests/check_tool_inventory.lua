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
validate_unique_nonempty(tools.system_tools, "system_tools")

local mason_names = {}
for _, entry in ipairs(tools.mason_packages) do
    if type(entry) ~= "table" or type(entry[1]) ~= "string" or entry[1] == "" then
        table.insert(failures, "mason_packages contains an invalid package entry")
    elseif type(entry.version) ~= "string" or entry.version == "" then
        table.insert(failures, entry[1] .. " is missing mason-tool-installer version")
    else
        table.insert(mason_names, entry[1])
    end
end
validate_unique_nonempty(mason_names, "mason_packages")

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
