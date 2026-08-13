-- 工具清单健全性：名称唯一、非空、覆盖完整。

local util = require("config.util")
local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

local function validate_unique(values, label)
    local seen = {}
    for _, value in ipairs(values) do
        check(type(value) == "string" and value ~= "", label .. " 含非法名称")
        check(not seen[value], label .. " 含重复项：" .. tostring(value))
        seen[value] = true
    end
end

validate_unique(util.lsp_servers, "lsp_servers")
validate_unique(util.mason_formatters, "mason_formatters")
validate_unique(util.mason_packages, "mason_packages")
validate_unique(util.system_tools, "system_tools")
check(
    #util.mason_packages == #util.lsp_servers + #util.mason_formatters,
    "mason_packages 必须恰好覆盖每个 LSP 服务器与格式化器一次"
)

if #failures > 0 then
    io.stderr:write("TOOL_INVENTORY_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write(
    ("TOOL_INVENTORY_CHECK_OK lsp=%d formatters=%d system=%d\n"):format(
        #util.lsp_servers,
        #util.mason_formatters,
        #util.system_tools
    )
)
if not vim.g.config_test_runner then vim.cmd("qa") end
