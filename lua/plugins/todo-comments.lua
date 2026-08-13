-- TODO/FIX/HACK 注释高亮与搜索（经 vim.pack）
--
-- 通过 :TodoFzfLua 与 fzf-lua 集成。
-- 懒加载：setup 延迟到第一个文件打开，避免启动期的多余工作。

vim.pack.add({
    { src = "https://github.com/folke/todo-comments.nvim" },
})

-- 延迟到缓冲区实际打开后再 setup。
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("todo_comments_lazy", { clear = true }),
    once = true,
    callback = function() require("todo-comments").setup() end,
})
