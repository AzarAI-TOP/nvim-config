-- Resolve the shared tool inventory to concrete Mason package names and verify
-- installation state. Used by bootstrap scripts, health checks, and tests.

local M = {}

function M.resolve_packages()
    local tools = require("config.tools")
    local mappings = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
    local packages = vim.deepcopy(tools.mason_formatters)
    local unmapped = {}

    for _, server in ipairs(tools.lsp_servers) do
        local package_name = mappings[server]
        if package_name then
            table.insert(packages, package_name)
        else
            table.insert(unmapped, server)
        end
    end

    table.sort(packages)
    table.sort(unmapped)
    return packages, unmapped
end

function M.missing_packages()
    local installed = {}
    for _, name in ipairs(require("mason-registry").get_installed_package_names()) do
        installed[name] = true
    end

    local packages, unmapped = M.resolve_packages()
    local missing = {}
    for _, package_name in ipairs(packages) do
        if not installed[package_name] then table.insert(missing, package_name) end
    end
    return missing, unmapped
end

function M.assert_all_installed()
    local missing, unmapped = M.missing_packages()
    if #missing > 0 or #unmapped > 0 then
        if #unmapped > 0 then io.stderr:write("Unmapped LSP servers: " .. table.concat(unmapped, ", ") .. "\n") end
        if #missing > 0 then io.stderr:write("Missing Mason packages: " .. table.concat(missing, ", ") .. "\n") end
        io.stderr:flush()
        vim.cmd("cquit 1")
        return false
    end

    local packages = M.resolve_packages()
    print("MASON_VERIFY_OK packages=" .. #packages)
    return true
end

return M
