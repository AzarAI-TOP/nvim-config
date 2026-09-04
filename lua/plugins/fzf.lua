-- Fuzzy finding (fzf-lua) — lazy loaded.
--
-- The first <leader>f* press pulls the plugin in: those keymap callbacks
-- (config/keymaps.lua) already require("fzf-lua") lazily, and the preload
-- stubs below turn that require into the load trigger. fzf-lua.utils is
-- stubbed too (the notifications picker uses its ANSI helpers). No setup()
-- call: fzf-lua applies its defaults without one.

require("config.lazy").defer("fzf-lua", {
    mods = { "fzf-lua", "fzf-lua.utils" },
    loader = function()
        vim.pack.add({
            { src = "https://github.com/ibhagwan/fzf-lua" },
        })
    end,
})
