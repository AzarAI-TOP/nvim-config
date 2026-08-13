-- TODO/FIX/HACK comment highlighting and search (via vim.pack)
--
-- Integrates with fzf-lua through :TodoFzfLua.
-- Lazy-loaded: setup is deferred until the first file opens, avoiding extra
-- startup work.

vim.pack.add({
    { src = "https://github.com/folke/todo-comments.nvim" },
})

-- Defer setup until a buffer actually opens.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("todo_comments_lazy", { clear = true }),
    once = true,
    callback = function() require("todo-comments").setup() end,
})
