-- Unit tests for config.mason_verify with injected fake registry and fake
-- lspconfig mapping. The disposable test environment has no Mason registry
-- cache (get_mason_map() resolves to {} and no packages are installed), so
-- every test injects fakes; nothing here touches the network or real Mason.
--
-- Version semantics under test mirror the pinned mason.nvim API exactly:
-- Package:get_installed_version() returns the `version` component of the
-- install receipt's source PURL (percent-decoded; `#subpath` and `?qualifiers`
-- are excluded, no prefix stripping), compared by plain string equality --
-- the same comparison the pinned mason-tool-installer performs.

local mason_verify = require("config.mason_verify")
local tools = require("config.tools")

local failures = {}

local function assert_true(cond, label)
    if not cond then table.insert(failures, label) end
end

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        table.insert(failures, ("%s: expected %s got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

-- Mirrors the pinned mason-lspconfig rev (a4068c3e) lspconfig_to_package
-- mapping; the standalone real-registry probe validates it against the live
-- install.
local REGISTRY_NAMES = {
    gopls = "gopls",
    clangd = "clangd",
    rust_analyzer = "rust-analyzer",
    ts_ls = "typescript-language-server",
    html = "html-lsp",
    cssls = "css-lsp",
    jsonls = "json-lsp",
    pyright = "pyright",
    lua_ls = "lua-language-server",
    bashls = "bash-language-server",
    yamlls = "yaml-language-server",
    kotlin_lsp = "kotlin-lsp",
}

-- Build a fake world where every resolved package is installed at its pinned
-- version unless overridden.
--   opts.versions[pkg] = installed version (string override)
--   opts.missing       = packages absent from the installed set
--   opts.unmapped      = aliases to drop from the injected mapping
--   opts.broken[pkg]   = "no_receipt" (installed, version nil) or "error"
--                        (registry.get_package raises)
local function make_world(opts)
    opts = opts or {}
    local mapping = vim.deepcopy(REGISTRY_NAMES)
    for _, alias in ipairs(opts.unmapped or {}) do
        mapping[alias] = nil
    end

    local versions = {} -- package -> installed version (nil = not installed)
    for _, name in ipairs(tools.mason_formatters) do
        versions[name] = tools.mason_versions[name]
    end
    for _, alias in ipairs(tools.lsp_servers) do
        if mapping[alias] then versions[mapping[alias]] = tools.mason_versions[alias] end
    end
    for pkg, version in pairs(opts.versions or {}) do
        versions[pkg] = version
    end
    for _, pkg in ipairs(opts.missing or {}) do
        versions[pkg] = nil
    end

    local installed_names = {}
    for pkg, version in pairs(versions) do
        if version ~= nil then table.insert(installed_names, pkg) end
    end
    table.sort(installed_names)

    local broken = opts.broken or {}
    local registry = {
        get_installed_package_names = function() return vim.deepcopy(installed_names) end,
        get_package = function(name)
            if broken[name] == "error" then error("Cannot find package " .. name) end
            if versions[name] == nil then error("No installed package found by the name '" .. name .. "'") end
            return {
                get_installed_version = function()
                    if broken[name] == "no_receipt" then return nil end
                    return versions[name]
                end,
            }
        end,
    }
    return registry, mapping
end

-- Run fn with injected fakes; always restores the real seams.
local function with_world(opts, fn)
    local registry, mapping = make_world(opts)
    local orig_registry, orig_mapping = mason_verify._registry, mason_verify._lspconfig_to_package
    mason_verify._registry, mason_verify._lspconfig_to_package = registry, mapping
    local ok, err = pcall(fn)
    mason_verify._registry, mason_verify._lspconfig_to_package = orig_registry, orig_mapping
    if not ok then error(err) end
end

-- Capture vim.cmd and io.stderr writes; returns the captured text.
local function capture_output()
    local buf = {}
    local orig_cmd, orig_stderr = vim.cmd, io.stderr
    vim.cmd = function(c) table.insert(buf, "CMD:" .. tostring(c) .. "\n") end
    io.stderr = { write = function(_, s) table.insert(buf, s) end, flush = function() end }
    return function()
        vim.cmd, io.stderr = orig_cmd, orig_stderr
        return table.concat(buf, "")
    end
end

-- 1. Exact match: every package installed at its pinned version passes.
with_world({}, function()
    local state = mason_verify.verify_state()
    assert_eq(#state.missing, 0, "exact match: missing")
    assert_eq(#state.unmapped, 0, "exact match: unmapped")
    assert_eq(#state.mismatched, 0, "exact match: mismatched")

    local packages = mason_verify.resolve_packages()
    assert_eq(#packages, #tools.lsp_servers + #tools.mason_formatters, "exact match: resolved package count")

    local ok = mason_verify.assert_all_installed()
    assert_eq(ok, true, "exact match: assert_all_installed returns true")
end)

-- 2. Missing package: installed set lacks taplo.
with_world({ missing = { "taplo" } }, function()
    local state = mason_verify.verify_state()
    assert_eq(#state.missing, 1, "missing: count")
    assert_eq(state.missing[1], "taplo", "missing: name")
    assert_eq(#state.unmapped, 0, "missing: unmapped")
    assert_eq(#state.mismatched, 0, "missing: mismatched")
end)

-- 3. Unmapped alias: kotlin_lsp has no registry package in the mapping.
with_world({ unmapped = { "kotlin_lsp" } }, function()
    local state = mason_verify.verify_state()
    assert_eq(#state.unmapped, 1, "unmapped: count")
    assert_eq(state.unmapped[1], "kotlin_lsp", "unmapped: name")
    assert_eq(#state.missing, 0, "unmapped: missing")
    assert_eq(#state.mismatched, 0, "unmapped: mismatched")
    for _, name in ipairs(state.missing) do
        assert_true(name ~= "kotlin-lsp", "unmapped: kotlin-lsp not reported missing")
    end
end)

-- 4. Version mismatch: representative opaque strings, exact equality, no
-- normalization. Mirrors the real drift observed in the local install.
with_world({
    versions = {
        ["lua-language-server"] = "3.18.2", -- pin 3.19.0
        ["rust-analyzer"] = "2026-07-20", -- pin 2026-08-10.1 (date release)
        ["kotlin-lsp"] = "kotlin-lsp/v262.8190.0", -- pin kotlin-lsp/v262.9593.0 (qualified tag)
        gopls = "v0.22.0", -- pin v0.23.0 (v-prefix preserved, no stripping)
        goimports = "0.48.0", -- pin v0.48.0 (installed without v must still mismatch)
    },
}, function()
    local state = mason_verify.verify_state()
    assert_eq(#state.missing, 0, "mismatch: missing")
    assert_eq(#state.unmapped, 0, "mismatch: unmapped")
    assert_eq(#state.mismatched, 5, "mismatch: count")
    local by_pkg = {}
    for _, m in ipairs(state.mismatched) do
        by_pkg[m.package] = m
    end
    assert_eq(by_pkg["lua-language-server"].expected, "3.19.0", "mismatch: lua expected")
    assert_eq(by_pkg["lua-language-server"].actual, "3.18.2", "mismatch: lua actual")
    assert_eq(by_pkg["rust-analyzer"].expected, "2026-08-10.1", "mismatch: rust-analyzer expected")
    assert_eq(by_pkg["rust-analyzer"].actual, "2026-07-20", "mismatch: rust-analyzer actual")
    assert_eq(by_pkg["kotlin-lsp"].expected, "kotlin-lsp/v262.9593.0", "mismatch: kotlin expected")
    assert_eq(by_pkg["kotlin-lsp"].actual, "kotlin-lsp/v262.8190.0", "mismatch: kotlin actual")
    assert_eq(by_pkg["gopls"].expected, "v0.23.0", "mismatch: gopls expected")
    assert_eq(by_pkg["gopls"].actual, "v0.22.0", "mismatch: gopls actual")
    assert_eq(by_pkg["goimports"].expected, "v0.48.0", "mismatch: goimports expected")
    assert_eq(by_pkg["goimports"].actual, "0.48.0", "mismatch: goimports actual (no implicit v-strip)")
    -- v-prefixed pins that DO match must not be flagged.
    assert_true(by_pkg["shfmt"] == nil, "mismatch: shfmt v3.13.1 exact match not flagged")
    assert_true(by_pkg["stylua"] == nil, "mismatch: stylua v2.5.2 exact match not flagged")
end)

-- 5. assert_all_installed fails, cquits, and prints expected/actual.
with_world({ versions = { ["lua-language-server"] = "3.18.2" } }, function()
    local restore = capture_output()
    local ok = mason_verify.assert_all_installed()
    local out = restore()
    assert_eq(ok, false, "assert_all_installed: returns false on mismatch")
    assert_true(out:find("cquit 1", 1, true) ~= nil, "assert_all_installed: emits cquit 1")
    assert_true(
        out:find("Mason version mismatch: lua-language-server expected=3.19.0 actual=3.18.2", 1, true) ~= nil,
        "assert_all_installed: actionable expected/actual message"
    )
end)

-- 6. Installed but unreportable: no receipt (nil version) or unresolvable
-- registry package both count as mismatches with actual=nil, never a crash.
with_world({
    broken = {
        ["lua-language-server"] = "no_receipt",
        ["rust-analyzer"] = "error",
    },
}, function()
    local state = mason_verify.verify_state()
    assert_eq(#state.missing, 0, "broken: missing")
    assert_eq(#state.mismatched, 2, "broken: mismatched count")
    local by_pkg = {}
    for _, m in ipairs(state.mismatched) do
        by_pkg[m.package] = m
    end
    assert_eq(by_pkg["lua-language-server"].expected, "3.19.0", "broken: no_receipt expected")
    assert_eq(by_pkg["lua-language-server"].actual, nil, "broken: no_receipt actual nil")
    assert_eq(by_pkg["rust-analyzer"].expected, "2026-08-10.1", "broken: unresolvable expected")
    assert_eq(by_pkg["rust-analyzer"].actual, nil, "broken: unresolvable actual nil")
end)

if #failures > 0 then
    io.stderr:write("MASON_VERIFY_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    io.stderr:flush()
    vim.cmd("cquit 1")
end

io.stdout:write(("MASON_VERIFY_CHECK_OK cases=6\n"):format())
if not vim.g.config_test_runner then vim.cmd("qa") end
