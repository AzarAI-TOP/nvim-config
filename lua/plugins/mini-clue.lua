-- ~/.config/nvim/lua/plugins/mini-clue.lua
-- Key discovery (mini.clue, via vim.pack)
--
-- Shows available keybindings in a floating window when a prefix key is
-- pressed. Configured for all <leader> prefix groups used in this config.

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.clue" },
})

local miniclue = require("mini.clue")

miniclue.setup({
    triggers = {
        -- Leader key groups
        { mode = "n", keys = "<leader>b", desc = "+buffer" },
        { mode = "n", keys = "<leader>c", desc = "+config" },
        { mode = "n", keys = "<leader>l", desc = "+language" },
        { mode = "n", keys = "<leader>f", desc = "+find" },
        { mode = "n", keys = "<leader>w", desc = "+window" },
        { mode = "n", keys = "<leader>t", desc = "+toggle" },
        { mode = "n", keys = "<leader>p", desc = "+package" },
        { mode = "n", keys = "<leader>s", desc = "+split" },
        { mode = "n", keys = "<leader>e", desc = "File explorer" },
        { mode = "n", keys = "<leader>nh", desc = "Clear search highlight" },
        { mode = "n", keys = "<leader>q", desc = "Quit" },
        { mode = "n", keys = "<leader>Q", desc = "Quit all" },
        { mode = "n", keys = "<leader>y", desc = "Copy to host clipboard" },
        { mode = "n", keys = "<leader>Y", desc = "Copy line to host clipboard" },
    },

    clues = {
        miniclue.gen_clues.builtin_completion(),
    },

    window = {
        delay = 300,
        config = {
            border = "rounded",
        },
    },
})
