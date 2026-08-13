-- Resolve the shared tool inventory to concrete Mason package names and verify
-- installation state and pinned versions. Used by bootstrap scripts, first-boot
-- integration checks, and tests.
--
-- Version semantics follow the pinned mason.nvim API exactly:
-- Package:get_installed_version() returns the `version` component of the
-- install receipt's source PURL (percent-decoded; `#subpath` and `?qualifiers`
-- are excluded, no prefix stripping). The pinned mason-tool-installer compares
-- that string against the configured `version` field with plain string
-- equality; this module mirrors that comparison -- no normalization.

local M = {}

-- Injectable seams for unit tests (fake registry / fake lspconfig mapping).
-- Defaults resolve lazily to the real modules so the production path is
-- unchanged. The disposable test environment has no registry cache, so tests
-- always inject fakes.
M._registry = nil
M._lspconfig_to_package = nil

local function registry()
    if M._registry then return M._registry end
    return require("mason-registry")
end

local function lspconfig_to_package()
    if M._lspconfig_to_package then return M._lspconfig_to_package end
    return require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
end

---Resolve the shared inventory to Mason registry package names.
---@param mapping? table<string, string> lspconfig alias -> registry package name
---@return string[] packages sorted
---@return string[] unmapped sorted (lspconfig servers with no registry package)
function M.resolve_packages(mapping)
    local tools = require("config.tools")
    local map = mapping or lspconfig_to_package()
    local packages = vim.deepcopy(tools.mason_formatters)
    local unmapped = {}
    for _, server in ipairs(tools.lsp_servers) do
        local package_name = map[server]
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

---Installed version as reported by the pinned mason-registry API, or nil when
---the package is installed but has no receipt or the registry cannot resolve
---it.
---@param package_name string
---@return string?
function M.get_installed_version(package_name)
    local ok, pkg = pcall(registry().get_package, package_name)
    if not ok then return nil end
    return pkg:get_installed_version()
end

---Pinned version per registry package name, resolved through the alias
---mapping (formatters are already registry names).
---@param mapping table<string, string>
---@return table<string, string>
local function package_pins(mapping)
    local tools = require("config.tools")
    local pins = {}
    for _, name in ipairs(tools.mason_formatters) do
        pins[name] = tools.mason_versions[name]
    end
    for _, server in ipairs(tools.lsp_servers) do
        local package_name = mapping[server]
        if package_name then pins[package_name] = tools.mason_versions[server] end
    end
    return pins
end

---Verify presence and pinned versions. Never touches the network and never
---installs or updates anything; it only reads installed package names and
---receipts (or the injected fakes).
---@return { missing: string[], unmapped: string[], mismatched: { package: string, expected: string, actual: string? }[] }
function M.verify_state()
    local map = lspconfig_to_package()
    local installed = {}
    for _, name in ipairs(registry().get_installed_package_names()) do
        installed[name] = true
    end

    local packages, unmapped = M.resolve_packages(map)
    local pins = package_pins(map)
    local missing, mismatched = {}, {}
    for _, package_name in ipairs(packages) do
        if not installed[package_name] then
            table.insert(missing, package_name)
        else
            local expected = pins[package_name]
            local actual = M.get_installed_version(package_name)
            if actual ~= expected then
                table.insert(mismatched, { package = package_name, expected = expected, actual = actual })
            end
        end
    end
    return { missing = missing, unmapped = unmapped, mismatched = mismatched }
end

---Fail (cquit 1) unless every package is installed at its pinned version.
---Prints actionable expected/actual output on mismatch.
---@return boolean
function M.assert_all_installed()
    local state = M.verify_state()
    local ok = #state.missing == 0 and #state.unmapped == 0 and #state.mismatched == 0
    if not ok then
        local lines = {}
        if #state.unmapped > 0 then
            table.insert(lines, "Unmapped LSP servers: " .. table.concat(state.unmapped, ", "))
        end
        if #state.missing > 0 then
            table.insert(lines, "Missing Mason packages: " .. table.concat(state.missing, ", "))
        end
        for _, m in ipairs(state.mismatched) do
            table.insert(
                lines,
                ("Mason version mismatch: %s expected=%s actual=%s"):format(m.package, m.expected, tostring(m.actual))
            )
        end
        io.stderr:write(table.concat(lines, "\n") .. "\n")
        io.stderr:flush()
        vim.cmd("cquit 1")
        return false
    end

    local packages = M.resolve_packages()
    print("MASON_VERIFY_OK packages=" .. #packages)
    return true
end

return M
