-- ~/.config/nvim/lua/plugins/tokyonight.lua
-- Tokyo Night theme with event-scoped setup.
--
-- vim.pack makes the colorscheme loader available in phase one. The plugin's
-- Lua setup runs only when a Tokyo Night colorscheme is requested; startup then
-- requests the configured theme normally. ColorScheme (post-load) cannot be the
-- loading trigger because that would create a circular dependency.

vim.pack.add({
    { src = "https://github.com/folke/tokyonight.nvim" },
})

vim.api.nvim_create_autocmd("ColorSchemePre", {
    group = vim.api.nvim_create_augroup("tokyonight_lazy_setup", { clear = true }),
    pattern = "tokyonight*",
    once = true,
    callback = function() require("tokyonight").setup({ style = "moon" }) end,
})

vim.cmd.colorscheme("tokyonight-moon")
