-- UI adaptation layer for noice.nvim and mini.notify on top of TokyoNight moon.
--
-- Philosophy: the colorscheme owns everything it defines. This module exists
-- only for what a colorscheme CANNOT express:
--   1. Translucent float surfaces (Pmenu / NoiceCmdlinePopup / MiniNotifyNormal,
--      blend=85) — Neovide ignores bg=NONE and winblend on floating windows and
--      renders them opaque; the highlight blend attribute is the only lever,
--      and blend=100 is broken (renders opaque), so 85 is the ceiling.
--   2. Per-kind popupmenu colors (NoiceCompletionItemKind<Name>) — noice's
--      private groups; without definitions here every kind renders in one
--      color (Special) via noice's default link.
--   3. The completion kind metadata (icon + color) consumed by noice.lua via
--      kind_icons().
--   4. The selected-row color (#2b3d73), a design decision matching Visual.
--
-- Group definitions are non-default, applied before the plugins load (this
-- module runs in the core config phase), so the plugins' `default=true` links
-- leave them untouched. Re-applied on every ColorScheme event.

-- Moon palette values used here (kept local so this module stays independent
-- of the colorscheme's internal tables).
local C = {
    bg_popup = "#1e2030", -- moon bg_dark: popup background (mostly blended away)
    bg_sel = "#2b3d73", -- blue0 blended into bg_popup at 40%, matches Visual
    blue = "#82aaff",
    comment = "#636da6",
    cyan = "#86e1fc",
    fg = "#c8d3f5",
    magenta = "#c099ff",
    orange = "#ff966c",
    purple = "#fca7ea",
    red = "#ff757f",
    teal = "#4fd6be",
    yellow = "#ffc777",
}

-- Completion kinds: single source of truth for the popupmenu's per-kind icon
-- (consumed by plugins/noice.lua via kind_icons()) and per-kind highlight
-- color (NoiceCompletionItemKind<Name> groups). noice renders icon + full kind
-- name per row.
local KINDS = {
    Text = { icon = "󰉿", color = C.fg },
    Method = { icon = "󰆧", color = C.blue },
    Function = { icon = "󰊕", color = C.blue },
    Constructor = { icon = "󰆧", color = C.cyan },
    Field = { icon = "󰜢", color = C.cyan },
    Variable = { icon = "󰆦", color = C.cyan },
    Class = { icon = "󰠗", color = C.yellow },
    Interface = { icon = "󰛦", color = C.magenta },
    Module = { icon = "󰏗", color = C.purple },
    Property = { icon = "󰜢", color = C.cyan },
    Unit = { icon = "󰑭", color = C.teal },
    Value = { icon = "󰎠", color = C.orange },
    Enum = { icon = "󰒻", color = C.orange },
    Keyword = { icon = "󰌋", color = C.purple },
    Snippet = { icon = "󰩫", color = C.teal },
    Color = { icon = "󰏘", color = C.red },
    File = { icon = "󰈔", color = C.comment },
    Reference = { icon = "󰈇", color = C.comment },
    Folder = { icon = "󰉋", color = C.comment },
    EnumMember = { icon = "󰒼", color = C.orange },
    Constant = { icon = "󰏿", color = C.orange },
    Struct = { icon = "󰙅", color = C.yellow },
    Event = { icon = "󰅱", color = C.yellow },
    Operator = { icon = "󰆕", color = C.red },
    TypeParameter = { icon = "󰊄", color = C.yellow },
    Macro = { icon = "󰁋", color = C.orange },
}

local M = {}

--- Kind icons in noice's `popupmenu.kind_icons` shape (icon + trailing space).
function M.kind_icons()
    local out = {}
    for name, spec in pairs(KINDS) do
        out[name] = spec.icon .. " "
    end
    return out
end

local function apply()
    -- Skip when a different colorscheme is active: the groups below are tuned
    -- for TokyoNight moon and would clash with other palettes.
    if vim.g.colors_name and not vim.g.colors_name:match("^tokyonight") then return end

    -- Translucent float surfaces via hl blend=85: Neovide ignores bg=NONE and
    -- winblend on floating windows, but honors the blend attribute (verified
    -- with a marker-pixel test); blend=100 is a Neovide edge case that renders
    -- opaque, so 85 is the working ceiling. The selected popup row stays
    -- opaque as the selection anchor.
    vim.api.nvim_set_hl(0, "Pmenu", { bg = C.bg_popup, fg = C.fg, blend = 85 })
    vim.api.nvim_set_hl(0, "PmenuSel", { bg = C.bg_sel })
    vim.api.nvim_set_hl(0, "NoiceCmdlinePopup", { bg = C.bg_popup, blend = 85 })
    vim.api.nvim_set_hl(0, "MiniNotifyNormal", { bg = C.bg_popup, blend = 85 })

    for name, spec in pairs(KINDS) do
        vim.api.nvim_set_hl(0, "NoiceCompletionItemKind" .. name, { fg = spec.color })
    end
end

-- Re-apply after any colorscheme load (tokyonight loads via plugins/tokyonight.lua).
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ui_adaptation_colors", { clear = true }),
    callback = apply,
})

apply()

return M
