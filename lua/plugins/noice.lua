-- noice.nvim: styled floating UIs replacing the native cmdline, messages, and
-- completion popupmenu (nui backend). noice also owns vim.notify: the notify
-- view falls back to noice's built-in "mini" backend (nvim-notify is not
-- installed), rendering notifications as unfocusable floating cards — the
-- card lifetime is bumped to 5s, matching the mini.notify defaults this
-- replaces. Colors and popupmenu kind metadata live in config/colors.lua.

local colors = require("config.colors")

vim.pack.add({
    { src = "https://github.com/folke/noice.nvim" },
    { src = "https://github.com/MunifTanjim/nui.nvim" },
})

require("noice").setup({
    -- ── Views ──
    views = {
        popupmenu = {
            -- The default popupmenu view ships a border config without a style
            -- (noice then renders no border); pin rounded explicitly.
            border = { style = "rounded" },
            size = { max_height = 10 }, -- match the previous pumheight=10 cap
        },
        -- Notification cards (vim.notify and routed msg_show): unfocusable by
        -- noice's own default; 5s lifetime (noice default is 2s).
        mini = { timeout = 5000 },
    },
    -- ── Completion popupmenu ──
    popupmenu = {
        kind_icons = colors.kind_icons(), -- Nerd Font icons + per-kind colors
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
