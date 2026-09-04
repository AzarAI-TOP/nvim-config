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
--      The hue follows the current mode (set_mode_gradient).
--
-- Group definitions are non-default, applied before the plugins load (this
-- module runs in the core config phase), so plugins' `default=true` links
-- (e.g. mini.notify's MiniNotifyNormal) leave them untouched. Re-applied on
-- every ColorScheme event: plugins re-apply only their own groups, and a
-- colorscheme switch could clear the custom ones.

-- Moon palette values used here (kept local so this module stays independent
-- of the colorscheme's internal tables).
local C = {
    bg = "#222436", -- moon bg: main background, also the Neovide title bar
    bg_popup = "#1e2030", -- moon bg_dark: popup background
    bg_sel = "#2b3d73", -- blue0 blended into bg_popup at 40%, matches Visual
    blue = "#82aaff",
    comment = "#636da6",
    cyan = "#86e1fc",
    fg = "#c8d3f5",
    fg_dark = "#828bb8",
    green = "#c3e88d", -- moon green0: INSERT mode
    magenta = "#c099ff",
    orange = "#ff966c",
    purple = "#fca7ea",
    red = "#ff757f",
    teal = "#4fd6be",
    yellow = "#ffc777",
}

-- Linear blend of two #rrggbb colors; t=0 -> a, t=1 -> b.
local function blend(a, b, t)
    local function ch(s, i) return tonumber(s:sub(i, i + 1), 16) end
    local r = ch(a, 2) + (ch(b, 2) - ch(a, 2)) * t
    local g = ch(a, 4) + (ch(b, 4) - ch(a, 4)) * t
    local bl = ch(a, 6) + (ch(b, 6) - ch(a, 6)) * t
    return string.format("#%02x%02x%02x", r, g, bl)
end

-- Mode base colors (C entries; only INSERT green is new). Extended mode
-- chars fold into their family: V/s/S/\19 → v, ic/ix → i, Rc/Rx/Rv → R,
-- cv/cex → c; unknown states fall back to NORMAL.
local MODE_PALETTE = {
    n = C.blue,
    i = C.green,
    ic = C.green,
    ix = C.green,
    v = C.magenta,
    V = C.magenta,
    ["\22"] = C.magenta,
    s = C.magenta,
    S = C.magenta,
    ["\19"] = C.magenta,
    R = C.red,
    r = C.red,
    Rc = C.red,
    Rx = C.red,
    Rv = C.red,
    c = C.yellow,
    cv = C.yellow,
    cex = C.yellow,
    t = C.teal,
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

-- Single source for TokyoNight moon values used outside this module (the
-- Neovide title bar in config/neovide.lua reads bg/blue from here, so a
-- palette tweak never needs a second edit).
M.palette = C

--- Kind icons in noice's `popupmenu.kind_icons` shape (icon + trailing space).
function M.kind_icons()
    local out = {}
    for name, spec in pairs(KINDS) do
        out[name] = spec.icon .. " "
    end
    return out
end

-- Severity → fg color for the statusline diagnostic icons (see header,
-- item 5). Exported so statusline.lua can derive the group names from the
-- same keys (MiniStatuslineDiag<Name>).
M.diag_fg = { Error = C.red, Warn = C.yellow, Info = C.cyan, Hint = C.teal }

-- Rewrite the statusline gradient groups to the given mode's hue. Called from
-- statusline.lua on ModeChanged and from apply() on ColorScheme. Dark text
-- on the saturated steps (Peak/Bright) matches the mode block's own styling;
-- Peak sits one step below the mode block (20% toward bg) so the two
-- adjacent blocks stay distinct. Diag/FileBase keep Dim's bg (a %# switch to
-- a group without bg falls back to the default background).
function M.set_mode_gradient(mode_char)
    -- Same guard as apply(): the moon hues would clash with other palettes.
    if vim.g.colors_name and not vim.g.colors_name:match("^tokyonight") then return end
    local m = MODE_PALETTE[mode_char] or MODE_PALETTE.n
    local dim_bg = blend(m, C.bg_popup, 0.6) -- shared by Dim/FileBase/Diag
    vim.api.nvim_set_hl(0, "MiniStatuslineBright", { fg = C.bg_popup, bg = blend(m, C.bg_popup, 0.35) })
    -- Dim keeps the dark text: the filename dir part must stay dimmer than
    -- the bright basename (FileBase), which is the "not in cwd root" cue.
    vim.api.nvim_set_hl(0, "MiniStatuslineDim", { fg = C.fg_dark, bg = dim_bg })
    vim.api.nvim_set_hl(0, "MiniStatuslineCenter", { fg = C.fg_dark, bg = blend(m, C.bg_popup, 0.8) })
    vim.api.nvim_set_hl(0, "MiniStatuslinePeak", { fg = C.bg_popup, bg = blend(m, C.bg_popup, 0.2) })
    vim.api.nvim_set_hl(0, "MiniStatuslineFileBase", { fg = C.fg, bg = dim_bg })
    for sev, fg in pairs(M.diag_fg) do
        vim.api.nvim_set_hl(0, "MiniStatuslineDiag" .. sev, { fg = fg, bg = dim_bg })
    end
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

    -- Re-hue the gradient to the current mode; set_mode_gradient is the only
    -- writer of the MiniStatusline* groups.
    M.set_mode_gradient(vim.fn.mode())
end

-- Re-apply after any colorscheme load (tokyonight loads via plugins/tokyonight.lua).
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ui_adaptation_colors", { clear = true }),
    callback = apply,
})

apply()

return M
