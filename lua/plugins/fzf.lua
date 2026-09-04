-- Fuzzy finding (fzf-lua) — lazy loaded.
--
-- The first <leader>f* press pulls the plugin in: those keymap callbacks
-- (config/keymaps.lua) already require("fzf-lua") lazily, and the preload
-- stub below turns that require into the load trigger. Other consumers
-- (:PackList, noice's :Noice pick) also pcall-require the module, so they
-- trigger the load the same way. No setup() call: fzf-lua applies its
-- defaults without one.

require("config.lazy").defer("fzf-lua", {
    mods = { "fzf-lua" },
    loader = function()
        vim.pack.add({
            { src = "https://github.com/ibhagwan/fzf-lua" },
        })
    end,
})
