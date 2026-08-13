-- True hot reload of the core config layer (options / keymaps / autocmds /
-- Neovide settings / pack commands / LSP config).
--
-- Plugin setups are deliberately NOT re-run: plugin file changes (setup options,
-- treesitter parsers, colorscheme) still require a restart. reload restores:
--   1. Registered keymaps (deleted and rebuilt via the config.util registry)
--   2. User commands owned by this config (:PackUpdate / :PackList)
--   3. All config.* modules (package.loaded cleared, then re-required in
--      startup order); augroups all carry clear=true so re-running rebuilds them;
--      mini.clue is re-setup to refresh its triggers

local M = {}

local CORE = {
    "config.options",
    "config.keymaps",
    "config.autocmds",
    "config.neovide",
    "config.pack",
    "config.lsp",
}

-- Plugin modules safe to re-run (for refreshing state that depends on the
-- config above). mini.clue's triggers depend on registered keymaps.
local RERUN_PLUGIN = { "plugins.mini" }

local OWNED_COMMANDS = { "PackUpdate", "PackList" }

local function clear_owned_modules()
    for name in pairs(package.loaded) do
        -- config.util (keymap registry) and config.reload (this module) must survive.
        if name ~= "config.util" and name ~= "config.reload" then
            if name:match("^config%.") then package.loaded[name] = nil end
        end
    end
    -- RERUN_PLUGIN entries also need clearing, or re-require hits the cache and
    -- setup never actually re-runs.
    for _, name in ipairs(RERUN_PLUGIN) do
        package.loaded[name] = nil
    end
end

---Reload the core config layer. Safe to call repeatedly; an error in one module
---does not affect the others.
function M.reload()
    require("config.util").delete_all_keymaps()
    for _, cmd in ipairs(OWNED_COMMANDS) do
        pcall(vim.api.nvim_del_user_command, cmd)
    end

    clear_owned_modules()

    for _, name in ipairs(CORE) do
        local ok, err = pcall(require, name)
        if not ok then
            vim.notify("Reload failed " .. name .. ": " .. tostring(err), vim.log.levels.ERROR, { title = "reload" })
        end
    end
    for _, name in ipairs(RERUN_PLUGIN) do
        pcall(require, name)
    end

    vim.notify("Config reloaded (plugin setups were not re-run)", vim.log.levels.INFO)
end

return M
