-- 模糊查找（fzf-lua，经 vim.pack）

vim.pack.add({
    { src = "https://github.com/ibhagwan/fzf-lua" },
})

require("fzf-lua").setup()
