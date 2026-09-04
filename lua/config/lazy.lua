-- Native lazy loading on top of vim.pack (no plugin manager).
--
-- vim.pack has no lazy-loading triggers (its `load` option only controls
-- plugin/ sourcing), so this module defers the vim.pack.add call itself.
-- Triggers:
--   mods — package.preload stubs: the first require("mod") loads the plugin.
--          The config's keymap callbacks already require their modules inside
--          the callback, so existing mappings become triggers unchanged.
--   cmds — placeholder user commands that load the plugin, then replay the
--          real command (bang + args).
--   keys — placeholder mappings that load the plugin (its setup usually
--          installs the real mapping), then replay the keypress.
--
-- :ConfigReload safety: this module is exempted from reload's package.loaded
-- sweep (like config.util — see config/reload.lua), so loaders and stub state
-- survive. Stub commands and mappings are NOT in the keymap registry, so
-- reload cannot delete or duplicate them; re-running defer() for an already
-- loaded plugin is a no-op.
--
-- NVIM_BOOTSTRAP=1 runs every loader immediately at defer() time: the
-- bootstrap flow installs every plugin up front, preserving the
-- "headless first run installs everything" invariant.

local M = {}

-- name -> { loader = function, stubs = { preload = {mod}, cmds = {cmd}, maps = {{mode,lhs}} } }
local deferred = {}
-- Names already loaded (directly or via a trigger); makes defer() idempotent
-- when a plugin file is re-required (e.g. plugins.mini on :ConfigReload).
local loaded = {}

local function load_now(name)
    local d = deferred[name]
    if not d then return end
    deferred[name] = nil
    loaded[name] = true
    -- Drop this plugin's stubs before the loader runs: the loader's
    -- vim.pack.add sources plugin/ scripts whose own requires must resolve
    -- for real instead of re-entering the stubs.
    for _, mod in ipairs(d.stubs.preload) do
        package.preload[mod] = nil
    end
    for _, cmd in ipairs(d.stubs.cmds) do
        pcall(vim.api.nvim_del_user_command, cmd)
    end
    for _, m in ipairs(d.stubs.maps) do
        pcall(vim.keymap.del, m.mode, m.lhs)
    end
    d.loader()
end

---Defer a plugin's vim.pack.add + setup until its first use.
---@param name string stable identifier (convention: main module name)
---@param opts { loader: fun(), mods?: string[], cmds?: string[], keys?: {mode?: string, lhs: string}[] }
function M.defer(name, opts)
    if vim.env.NVIM_BOOTSTRAP == "1" then
        opts.loader()
        return
    end
    if loaded[name] then return end
    local d = { loader = opts.loader, stubs = { preload = {}, cmds = {}, maps = {} } }
    deferred[name] = d

    for _, mod in ipairs(opts.mods or {}) do
        table.insert(d.stubs.preload, mod)
        package.preload[mod] = function()
            -- The outer require has already put its in-progress sentinel into
            -- package.loaded; drop it so the nested require below loads the
            -- real module instead of tripping require's loop detection.
            package.loaded[mod] = nil
            load_now(name)
            -- The stub is gone; this require loads the real module and its
            -- return value becomes the result of the original require call.
            return require(mod)
        end
    end

    for _, cmd in ipairs(opts.cmds or {}) do
        table.insert(d.stubs.cmds, cmd)
        vim.api.nvim_create_user_command(cmd, function(e)
            load_now(name)
            vim.cmd({ cmd = cmd, bang = e.bang, args = e.fargs })
        end, { bang = true, nargs = "*", desc = "(loads " .. name .. ")" })
    end

    for _, k in ipairs(opts.keys or {}) do
        local mode, lhs = k.mode or "n", k.lhs
        table.insert(d.stubs.maps, { mode = mode, lhs = lhs })
        vim.keymap.set(mode, lhs, function()
            load_now(name)
            -- Deleting the stub above removed this very mapping while it is
            -- running (allowed); the loader's setup has typically installed
            -- the real mapping by now. Replay so that mapping — or the
            -- builtin, if setup maps nothing — handles this keypress.
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), "m", false)
        end, { desc = "(loads " .. name .. ")" })
    end
end

---Load a deferred plugin immediately (no-op for unknown/loaded names).
---@param name string
function M.load_now(name) load_now(name) end

---Load every deferred plugin. :PackUpdate calls this first: vim.pack.update
---and :PackList only see plugins that have been added, so deferred ones would
---otherwise be silently skipped.
function M.load_all()
    for _, name in ipairs(vim.tbl_keys(deferred)) do
        load_now(name)
    end
end

return M
