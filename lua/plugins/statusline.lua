-- Statusline: mini.statusline with custom content.
--
-- Layout (active window): mode (colored block) | cwd | git branch | filename,
-- then cursor location · diagnostics · LSP clients · encoding · filetype on
-- the right. Brightness runs bright → dim from both edges toward the center
-- (MiniStatuslineBright/Dim/Center/Peak groups in config/colors.lua); a
-- filename showing a relative path renders its basename in Bright while the
-- directory part keeps Dim, as a "not in the cwd root" reminder. Custom
-- sections: colored per-severity diagnostics (mini.statusline renders the
-- whole section in one flat group), LSP client names (section_lsp only
-- counts "+" per server), split encoding/filetype (no file size). TokyoNight
-- moon defines every MiniStatusline* group; the extra groups live in
-- config/colors.lua.

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.statusline" },
})

local MiniStatusline = require("mini.statusline")

-- One global statusline (mini.statusline's recommended setup).
vim.o.laststatus = 3

-- Per-severity diagnostic icons; colors come from the MiniStatuslineDiag*
-- groups in config/colors.lua. vim.diagnostic.count() is nvim-cached, so
-- this is cheap per refresh. Space after each icon keeps the glyph and count
-- apart (Nerd Font glyph metrics can overflow the cell otherwise). Each
-- fragment ends by switching back to the Dim group: "%*" would restore the
-- NORMAL background and break the section's background.
local DIAG_SEVERITIES = {
    { vim.diagnostic.severity.ERROR, "MiniStatuslineDiagError", "󰅚" },
    { vim.diagnostic.severity.WARN, "MiniStatuslineDiagWarn", "󰀪" },
    { vim.diagnostic.severity.INFO, "MiniStatuslineDiagInfo", "󰋽" },
    { vim.diagnostic.severity.HINT, "MiniStatuslineDiagHint", "󰌵" },
}

local function diagnostics()
    if MiniStatusline.is_truncated(60) or not vim.diagnostic.is_enabled({ bufnr = 0 }) then return "" end
    local counts = vim.diagnostic.count(0)
    local parts = {}
    for _, spec in ipairs(DIAG_SEVERITIES) do
        local n = counts[spec[1]] or 0
        if n > 0 then table.insert(parts, string.format("%%#%s#%s %d%%#MiniStatuslineDim#", spec[2], spec[3], n)) end
    end
    if #parts == 0 then return "" end
    return "[" .. table.concat(parts, " ") .. "]"
end

-- Sorted for stable output: client order can vary between refreshes.
local function lsp_clients()
    if MiniStatusline.is_truncated(60) then return "" end
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then return "" end
    local names = {}
    for _, client in ipairs(clients) do
        table.insert(names, client.name)
    end
    table.sort(names)
    return "󰰎 " .. table.concat(names, " ")
end

-- Working directory; hidden below 120 cols so narrow windows keep only the
-- mode, filename and the right side.
local function cwd()
    if MiniStatusline.is_truncated(120) then return "" end
    return vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
end

-- Branch from mini.git's buffer summary (empty outside git repos),
-- bracketed to match the diagnostics section.
local function git_branch()
    local git = MiniStatusline.section_git({ trunc_width = 120 })
    if git == "" then return "" end
    return "[" .. git .. "]"
end

-- Encoding · fileformat; no icon (the filetype segment carries it).
local function encoding()
    if MiniStatusline.is_truncated(60) or vim.bo.buftype ~= "" then return "" end
    if vim.bo.filetype == "" then return "" end
    local enc = vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
    return string.format("%s[%s]", enc, vim.bo.fileformat)
end

-- Icon from mini.icons when available (optional plugin); plain filetype otherwise.
local function filetype()
    if MiniStatusline.is_truncated(60) or vim.bo.buftype ~= "" then return "" end
    local ft = vim.bo.filetype
    if ft == "" then return "" end
    local icon = ""
    if _G.MiniIcons ~= nil then
        local ok, glyph = pcall(_G.MiniIcons.get, "filetype", ft)
        if ok and glyph ~= nil then icon = glyph .. " " end
    end
    return icon .. ft
end

-- Relative filename with modified/readonly flags; terminal buffers show the
-- job title via "%t". A path containing a directory renders the basename with
-- bright text (MiniStatuslineFileBase) while the directory part keeps the
-- Dim background, as a "file not in the cwd root" reminder. No %< truncation
-- point: on overflow nvim keeps the left part and shaves the right-aligned
-- side, so the filename never gets ellipsized.
local function filename()
    if vim.bo.buftype == "terminal" then return "%t" end
    local f = vim.fn.expand("%f")
    local flags = (vim.bo.modified and " [+]" or "") .. (vim.bo.readonly and " [RO]" or "")
    if f == "" then return flags end
    local dir, base = f:match("^(.*[/\\])([^/\\]*)$")
    if dir then return string.format("%s%%#MiniStatuslineFileBase#%s%%#MiniStatuslineDim#%s", dir, base, flags) end
    return f .. flags
end

-- Line:column plus file progress (current line / total).
local function location()
    if MiniStatusline.is_truncated(60) then return "" end
    return "%l:%v (%{float2nr(line('.')*100.0/line('$'))}%%)"
end

MiniStatusline.setup({
    content = {
        active = function()
            -- Below 120 cols: mode shrinks to 3 letters and cwd/git hide, so
            -- narrow windows keep mode + filename + the right side.
            local narrow = MiniStatusline.is_truncated(120)
            -- Empty args (no trunc_width): is_truncated() would force the
            -- short name.
            local mode, mode_hl = MiniStatusline.section_mode({})
            local mode_str = narrow and string.sub(mode, 1, 3) or mode

            return MiniStatusline.combine_groups({
                { hl = mode_hl, strings = { mode_str } },
                -- Location group (cwd + git) sits at Peak so it always
                -- differs from the filename segment below it.
                { hl = "MiniStatuslinePeak", strings = { cwd() } },
                { hl = "MiniStatuslinePeak", strings = { git_branch() } },
                { hl = "MiniStatuslineDim", strings = { filename() } },
                "%#StatusLine#", -- cut the filename background at its text
                "%= ", -- right-aligned remainder
                { hl = "MiniStatuslineCenter", strings = { location() } },
                { hl = "MiniStatuslineDim", strings = { diagnostics(), lsp_clients() } },
                { hl = "MiniStatuslineBright", strings = { encoding() } },
                { hl = "MiniStatuslinePeak", strings = { filetype() } },
            })
        end,
    },
})
