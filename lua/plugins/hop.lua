-- Character jumping (hop.nvim, via vim.pack)
-- Keymaps live in config/keymaps.lua: f = in-line search, F = whole-window search.

vim.pack.add({
    { src = "https://github.com/smoka7/hop.nvim" },
})

require("hop").setup({})
