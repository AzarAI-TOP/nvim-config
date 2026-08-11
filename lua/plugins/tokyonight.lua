-- ~/.config/nvim/lua/plugins/tokyonight.lua
-- Colorscheme (tokyonight, via vim.pack)
--
-- Loaded in phase 1 (infrastructure) to apply the colorscheme immediately
-- and avoid a visual flash during startup.

vim.pack.add({
    { src = "https://github.com/folke/tokyonight.nvim" },
})

require("tokyonight").setup({
    style = "moon",
})

vim.cmd.colorscheme("tokyonight-moon")
