-- noice.nvim: styled floating UIs replacing the native cmdline, messages, and
-- completion popupmenu (nui backend). Every notification — vim.notify calls
-- and native message-channel output (E-errors, warnings, echo) — renders as a
-- mini.notify card: mini.notify owns vim.notify directly (plugins/mini.lua),
-- and the adapter below lets noice's "notify" view reuse it, so nothing falls
-- back to the bottom MsgArea. Colors and popupmenu kind metadata live in
-- config/colors.lua.

local colors = require("config.colors")

vim.pack.add({
    { src = "https://github.com/folke/noice.nvim" },
    { src = "https://github.com/MunifTanjim/nui.nvim" },
})

-- Adapter: noice routes every msg_show (info / error / warning) to its
-- "notify" view, which calls require("notify") — nvim-notify's module. That
-- plugin is deliberately not installed, so without this adapter the view
-- falls back to the "mini" backend (bottom MsgArea). mini.notify implements
-- the same (msg, level) contract, so expose it under that module name.
-- Two contract gaps to bridge: make_notify() returns a vim.schedule_wrap C
-- closure, which cannot carry fields (noice also calls
-- require("notify").dismiss), hence the callable table wrapper; and it only
-- accepts numeric vim.log.levels, while noice passes "error"/"warn"/"info"
-- strings.
package.preload["notify"] = function()
    local mini_notify = require("mini.notify").make_notify()
    local level_numbers = {}
    for name, num in pairs(vim.log.levels) do
        level_numbers[name:lower()] = num
    end
    return setmetatable({}, {
        __call = function(_, msg, level, _)
            msg = msg or ""
            if type(level) == "string" then level = level_numbers[level:lower()] or vim.log.levels.INFO end
            return mini_notify(msg, level)
        end,
        __index = {
            -- nvim-notify API called on message clear; mini.notify has no
            -- pending queue, cards expire on their own — no-op.
            dismiss = function() end,
        },
    })
end

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
