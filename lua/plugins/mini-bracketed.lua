-- ~/.config/nvim/lua/plugins/mini-bracketed.lua
-- Bracket navigation (mini.bracketed, via vim.pack)
--
-- Disabled targets:
--   treesitter → conflicts with todo-comments ]t/[t

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.bracketed" },
})

require("mini.bracketed").setup({
    treesitter = { suffix = "" },
})
