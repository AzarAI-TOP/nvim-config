-- 缓冲区管理（bento.nvim，经 vim.pack）

vim.pack.add({
    { src = "https://github.com/serhez/bento.nvim" },
})

require("bento").setup({
    main_keymap = "<leader>bb",

    ui = {
        mode = "floating",
        floating = {
            position = "middle-right",
            border = "rounded",
        },
    },
})
