-- UI adaptation layer for noice.nvim and mini.notify on top of TokyoNight moon.
--
-- Philosophy: the colorscheme owns everything it defines. This module exists
-- only for what a colorscheme CANNOT express:
--   1. Float surface colors (Pmenu / NoiceCmdlinePopup / MiniNotifyNormal) —
--      fully opaque.
--   2. Per-kind popupmenu colors (NoiceCompletionItemKind<Name>) — noice's
--      private groups; without definitions here every kind renders in one
--      color (Special) via noice's default link.
--   3. The completion kind metadata (icon + color) consumed by noice.lua via
--      kind_icons().
--   4. The selected-row color (#2b3d73), a design decision matching Visual.
--   5. Per-severity statusline diagnostic icon colors — mini.statusline
--      renders the whole section in one highlight group, so the severity
--      colors have to come from here (MiniStatuslineDiag*).
--   6. The statusline brightness gradient: bright → dim from both edges
--      toward the centered location (MiniStatuslineBright/Dim/Center/Peak).
--
-- Group definitions are non-default, applied before the plugins load (this
-- module runs in the core config phase), so plugins' `default=true` links
-- (e.g. mini.notify's MiniNotifyNormal) leave them untouched. Re-applied on
-- every ColorScheme event: plugins re-apply only their own groups, and a
-- colorscheme switch could clear the custom ones.

-- Moon palette values used here (kept local so this module stays independent
-- of the colorscheme's internal tables).
local C = {
    bg_popup = "#1e2030", -- moon bg_dark: popup background
    bg_sel = "#2b3d73", -- blue0 blended into bg_popup at 40%, matches Visual
    bg_center = "#262b45", -- gradient midpoint between bg_dark and fg_gutter
    bg_bright = "#4b5582", -- step above fg_gutter
    bg_peak = "#5f6b9e", -- brightest step, toward fg_dark
    blue = "#82aaff",
    comment = "#636da6",
    cyan = "#86e1fc",
    fg = "#c8d3f5",
    fg_dark = "#828bb8",
    fg_gutter = "#3b4261",
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

    -- Float surface colors, fully opaque.
    vim.api.nvim_set_hl(0, "Pmenu", { bg = C.bg_popup, fg = C.fg })
    vim.api.nvim_set_hl(0, "PmenuSel", { bg = C.bg_sel })
    vim.api.nvim_set_hl(0, "NoiceCmdlinePopup", { bg = C.bg_popup })
    vim.api.nvim_set_hl(0, "MiniNotifyNormal", { bg = C.bg_popup })

    for name, spec in pairs(KINDS) do
        vim.api.nvim_set_hl(0, "NoiceCompletionItemKind" .. name, { fg = spec.color })
    end

    -- Statusline diagnostic icons (see header, item 5). The bg keeps the
    -- Dim step: the %#Group# switch inside the section would otherwise fall
    -- back to the default background and break the gradient.
    vim.api.nvim_set_hl(0, "MiniStatuslineDiagError", { fg = C.red, bg = C.fg_gutter })
    vim.api.nvim_set_hl(0, "MiniStatuslineDiagWarn", { fg = C.yellow, bg = C.fg_gutter })
    vim.api.nvim_set_hl(0, "MiniStatuslineDiagInfo", { fg = C.cyan, bg = C.fg_gutter })
    vim.api.nvim_set_hl(0, "MiniStatuslineDiagHint", { fg = C.teal, bg = C.fg_gutter })

    -- Statusline brightness steps (see header, item 6): moon fg_gutter as the
    -- middle step, brightened/darkened toward the edges / center. Peak is the
    -- rightmost filetype segment (brightest, mirroring the mode block).
    vim.api.nvim_set_hl(0, "MiniStatuslineBright", { fg = C.fg, bg = C.bg_bright })
    vim.api.nvim_set_hl(0, "MiniStatuslineDim", { fg = C.fg_dark, bg = C.fg_gutter })
    vim.api.nvim_set_hl(0, "MiniStatuslineCenter", { fg = C.fg_dark, bg = C.bg_center })
    vim.api.nvim_set_hl(0, "MiniStatuslinePeak", { fg = C.fg, bg = C.bg_peak })
    -- Basename highlight inside the filename segment: bright text on the
    -- same Dim background (a %# switch to a group without bg falls back to
    -- the default background, so the bg must be explicit).
    vim.api.nvim_set_hl(0, "MiniStatuslineFileBase", { fg = C.fg, bg = C.fg_gutter })
end

-- Re-apply after any colorscheme load (tokyonight loads via plugins/tokyonight.lua).
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ui_adaptation_colors", { clear = true }),
    callback = apply,
})

apply()

return M
