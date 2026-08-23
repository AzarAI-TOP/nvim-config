-- noice.nvim: styled floating UIs replacing the native cmdline, messages, and
-- completion popupmenu (nui backend). Notifications stay with mini.notify
-- (plugins/mini.lua) — noice's vim.notify routing is disabled here. Colors and
-- popupmenu kind metadata live in config/colors.lua.

local colors = require("config.colors")

vim.pack.add({
    { src = "https://github.com/folke/noice.nvim" },
    { src = "https://github.com/MunifTanjim/nui.nvim" },
})

require("noice").setup({
    -- ── Notifications ──
    -- mini.notify owns vim.notify; noice must not wrap it, otherwise the
    -- mini.notify override (installed earlier in the plugin phase) is replaced.
    notify = {
        enabled = false,
    },
    -- ── Completion popupmenu ──
    popupmenu = {
        kind_icons = colors.kind_icons(), -- Nerd Font icons + per-kind colors
    },
    -- ── Views ──
    views = {
        popupmenu = {
            -- The default popupmenu view ships a border config without a style
            -- (noice then renders no border); pin rounded explicitly.
            border = { style = "rounded" },
            size = { max_height = 10 }, -- match the previous pumheight=10 cap
        },
    },
    -- ── Presets ──
    presets = {
        bottom_search = true, -- classic bottom cmdline for search prompts
        command_palette = true, -- cmdline and popupmenu positioned together
        long_message_to_split = true, -- long messages render in a split
        inc_rename = false, -- inc-rename.nvim not installed
        lsp_doc_border = true, -- borders on hover docs and signature help
    },
})
