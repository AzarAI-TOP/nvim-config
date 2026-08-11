-- ~/.config/nvim/lua/plugins/todo-comments.lua
-- TODO/FIX/HACK comment highlighting & search (via vim.pack)
--
-- Integrates with fzf-lua via :TodoFzfLua.
-- Lazy-loaded: setup is deferred until the first file is opened to avoid
-- unnecessary work during startup.

vim.pack.add({
    { src = "https://github.com/folke/todo-comments.nvim" },
})

-- Defer setup until a buffer is actually opened.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("todo_comments_lazy", { clear = true }),
    once = true,
    callback = function() require("todo-comments").setup() end,
})
