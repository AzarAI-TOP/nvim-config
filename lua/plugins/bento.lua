-- Buffer management (bento.nvim, via vim.pack)

vim.pack.add({
    { src = "https://github.com/serhez/bento.nvim" },
})

require("bento").setup({
    main_keymap = ";",

    ui = {
        mode = "floating",
        floating = {
            position = "middle-right",
            border = "rounded",
        },
    },
})
