-- Real hot-reload for the core config layer (options, keymaps, autocmds,
-- Neovide settings, pack commands, LSP configs).
--
-- Plugin setups are intentionally NOT re-run: plugin-file changes (setup
-- options, treesitter parsers, colorscheme style) still require a restart.
-- What reload does restore:
--   1. tracked keymaps (deleted via config.keymaps_registry, then re-created)
--   2. user commands owned by this config (:PackUpdate / :PackList)
--   3. every config.* / lsp.* module (package.loaded cleared, re-required in
--      startup order); augroups already use clear=true so re-running rebuilds
--      them, and mini.clue is re-setup to refresh its triggers.

local M = {}

local CORE = {
    "config.options",
    "config.keymaps",
    "config.autocmds",
    "config.neovide",
    "config.pack",
    "config.lsp",
}

-- Re-setup-safe plugin modules (re-run to refresh state derived from the
-- config above). mini.clue's triggers depend on registered keymaps.
local RERUN_PLUGIN = { "plugins.mini-clue" }

local OWNED_COMMANDS = { "PackUpdate", "PackList" }

local function clear_owned_modules()
    for name in pairs(package.loaded) do
        if name ~= "config.keymaps_registry" and name ~= "config.reload" then
            if name:match("^config%.") or name:match("^lsp%.") then package.loaded[name] = nil end
        end
    end
end

---Reload the core config layer. Safe to call repeatedly; reports per-module
---errors without aborting the reload.
function M.reload()
    require("config.keymaps_registry").delete_all()
    for _, cmd in ipairs(OWNED_COMMANDS) do
        pcall(vim.api.nvim_del_user_command, cmd)
    end

    clear_owned_modules()

    for _, name in ipairs(CORE) do
        local ok, err = pcall(require, name)
        if not ok then
            vim.notify("重载失败 " .. name .. ": " .. tostring(err), vim.log.levels.ERROR, { title = "reload" })
        end
    end
    for _, name in ipairs(RERUN_PLUGIN) do
        pcall(require, name)
    end

    vim.notify("配置已重新加载（插件 setup 未重跑）", vim.log.levels.INFO)
end

return M
