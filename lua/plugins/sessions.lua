-- Named global sessions (mini.sessions): kept under stdpath("data")/session
-- so nothing is ever written into project directories, and auto-updated on
-- exit (autowrite default) after they have been read. Lazy loaded: the
-- <leader>S* callbacks in config/keymaps.lua require("mini.sessions")
-- lazily, which the preload stub turns into the load trigger.

require("config.lazy").defer("mini.sessions", {
    mods = { "mini.sessions" },
    loader = function()
        vim.pack.add({
            { src = "https://github.com/nvim-mini/mini.sessions" },
        })

        require("mini.sessions").setup()
    end,
})
