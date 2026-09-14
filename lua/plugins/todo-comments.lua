-- TODO/FIX/HACK comment highlighting and search (via vim.pack)
--
-- Integrates with fzf-lua through :TodoFzfLua.

vim.pack.add({
    { src = "https://github.com/folke/todo-comments.nvim" },
})

require("todo-comments").setup()
