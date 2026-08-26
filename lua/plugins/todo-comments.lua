-- TODO/FIX/HACK comment highlighting and search (via vim.pack)
--
-- Integrates with fzf-lua through :TodoFzfLua.
-- Setup runs eagerly like every other plugin: it is cheap, and deferring it
-- only created a window where ]t/[t and :TodoFzfLua exist but are unconfigured.

vim.pack.add({
    { src = "https://github.com/folke/todo-comments.nvim" },
})

require("todo-comments").setup()
