-- Tokyo Night colorscheme, event-scoped setup.
--
-- vim.pack makes the colorscheme loader available in the first phase; the
-- plugin's Lua setup only runs when the Tokyo Night colorscheme is requested;
-- the startup flow then requests the configured colorscheme normally.
-- ColorScheme (after loading) cannot serve as the load trigger — that would
-- create a circular dependency.

vim.pack.add({
    { src = "https://github.com/folke/tokyonight.nvim" },
})

vim.api.nvim_create_autocmd("ColorSchemePre", {
    group = vim.api.nvim_create_augroup("tokyonight_lazy_setup", { clear = true }),
    pattern = "tokyonight*",
    once = true,
    callback = function()
        -- transparent = true hands the background to the terminal: kitty renders
        -- its background_opacity only in cells that still use the default
        -- background, so an explicit Normal background paints opaque and the
        -- window padding around the editor reads as a frame in a different
        -- shade. kitty.conf sets its background to this same moon tone, so the
        -- padding and the editor canvas stay indistinguishable.
        require("tokyonight").setup({ style = "moon", transparent = true })
    end,
})

vim.cmd.colorscheme("tokyonight-moon")
