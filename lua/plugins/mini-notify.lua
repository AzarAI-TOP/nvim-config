-- 通知系统（mini.notify，经 vim.pack）

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.notify" },
})

require("mini.notify").setup({
    window = {
        config = {
            focusable = true,
        },
    },
})
