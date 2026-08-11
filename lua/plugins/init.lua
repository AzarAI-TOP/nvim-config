-- Plugin loader with explicit two-phase loading.
--
-- Phase 1 — Infrastructure: icons, mason, lspconfig, colorscheme.
--   Must load before any plugin that depends on them.
--
-- Phase 2 — Features: everything else, sorted for determinism.
--
-- To add a plugin: create lua/plugins/<name>.lua. If it must load in
-- phase 1, add the name to `phase_one` below. Otherwise it loads
-- automatically in phase 2.

-- Plugins that must load before any feature plugin.
local phase_one = {
    "mini-core", -- mini.icons and other core mini.* modules
    "mason", -- Mason + mason-tool-installer + nvim-lspconfig
    "tokyonight", -- Colorscheme (applied immediately to avoid flash)
}

-- Detect phase one modules for O(1) lookup.
local is_phase_one = {}
for _, name in ipairs(phase_one) do
    is_phase_one[name] = true
end

local dir = vim.fn.stdpath("config") .. "/lua/plugins"

-- Collect all plugin modules.
local all_modules = {}
for name, ftype in vim.fs.dir(dir) do
    if ftype == "file" and name:match("%.lua$") and name ~= "init.lua" then
        table.insert(all_modules, (name:gsub("%.lua$", "")))
    end
end
table.sort(all_modules)

-- Phase 1: load infrastructure plugins in explicit order.
for _, name in ipairs(phase_one) do
    require("plugins." .. name)
end

-- Phase 2: load remaining feature plugins, sorted for cross-platform determinism.
for _, name in ipairs(all_modules) do
    if not is_phase_one[name] then require("plugins." .. name) end
end
