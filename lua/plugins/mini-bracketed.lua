-- 括号导航（mini.bracketed，经 vim.pack）
--
-- 禁用的目标：
--   treesitter → 与 todo-comments 的 ]t/[t 冲突

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.bracketed" },
})

require("mini.bracketed").setup({
    treesitter = { suffix = "" },
})
