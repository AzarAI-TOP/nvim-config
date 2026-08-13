-- Shared tool inventory sanity: unique, non-empty names, complete coverage.

local tools = require("config.tools")
local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

local function validate_unique(values, label)
    local seen = {}
    for _, value in ipairs(values) do
        check(type(value) == "string" and value ~= "", label .. " contains an invalid name")
        check(not seen[value], label .. " contains duplicate: " .. tostring(value))
        seen[value] = true
    end
end

validate_unique(tools.lsp_servers, "lsp_servers")
validate_unique(tools.mason_formatters, "mason_formatters")
validate_unique(tools.mason_packages, "mason_packages")
validate_unique(tools.system_tools, "system_tools")
check(
    #tools.mason_packages == #tools.lsp_servers + #tools.mason_formatters,
    "mason_packages must cover every LSP server and formatter exactly once"
)

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
