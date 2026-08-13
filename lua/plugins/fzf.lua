-- Fuzzy finding (fzf-lua, via vim.pack)

vim.pack.add({
    { src = "https://github.com/ibhagwan/fzf-lua" },
})

require("fzf-lua").setup()
