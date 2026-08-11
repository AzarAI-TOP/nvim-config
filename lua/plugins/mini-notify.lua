-- ~/.config/nvim/lua/plugins/mini-notify.lua
-- Notification system (mini.notify, via vim.pack)

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
