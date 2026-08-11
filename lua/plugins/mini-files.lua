-- ~/.config/nvim/lua/plugins/mini-files.lua
-- File explorer (mini.files, via vim.pack)
--
-- Uses Miller columns navigation.
-- Replaces netrw as the default file explorer.
-- Automatically uses mini.icons for file icons when available.

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.files" },
})

require("mini.files").setup({
    options = {
        -- Replace netrw for `:e <dir>` and similar
        use_as_default_explorer = true,
    },
    windows = {
        preview = true, -- Show file preview under cursor
    },
})
