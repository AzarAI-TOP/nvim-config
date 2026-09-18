-- noice.nvim: styled floating UIs replacing the native cmdline, messages, and
-- completion popupmenu (nui backend). Notifications route to noice's `notify`
-- view, backed by nvim-notify (noice's health check requires one of
-- nvim-notify / snacks.nvim for that view); background_colour is pinned
-- because nvim-notify's default transparent blend renders black message
-- cards on Windows. Colors and popupmenu kind metadata live in
-- config/colors.lua.

local colors = require("config.colors")

vim.pack.add({
    { src = "https://github.com/folke/noice.nvim" },
    { src = "https://github.com/MunifTanjim/nui.nvim" },
    { src = "https://github.com/rcarriga/nvim-notify" },
})

require("notify").setup({ background_colour = "#000000" })

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
    -- ── LSP ──
    lsp = {
        -- Route LSP hover/signature markdown through noice's formatter
        -- (fenced-code-block aware) instead of the stock vim.lsp.util ones.
        override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
        },
    },
})
