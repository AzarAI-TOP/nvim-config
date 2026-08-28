-- Statusline: mini.statusline with custom content.
--
-- Layout (active window): mode (colored block) | cwd | git branch | filename,
-- then cursor location · diagnostics · LSP clients · encoding · filetype on
-- the right. Brightness runs bright → dim from both edges toward the center,
-- re-hued to the current mode's color on every ModeChanged
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

-- Narrow-layout threshold: one third of the primary screen width, in
-- columns. Screen and window pixel widths come from a background PowerShell
-- probe (GetWindowRect on this instance's Neovide window, located via the
-- nvim process's parent — with several instances open, "first neovide
-- found" could measure a differently sized one) and are cached in the state
-- dir; 120 is the fallback until the probe lands.
local narrow_threshold = 120

local function apply_probe(out)
    local sw, ww = out:match("(%d+)%s+(%d+)")
    sw, ww = tonumber(sw), tonumber(ww)
    if not sw or sw <= 0 or not ww or ww <= 0 or vim.o.columns <= 0 then return false end
    local px_per_col = ww / vim.o.columns
    -- Reject nonsense ratios (e.g. pre-attach UI sizes); ~8-11px at 13pt.
    if px_per_col < 5 or px_per_col > 16 then return false end
    narrow_threshold = math.max(40, math.floor(sw / 3 / px_per_col))
    return true
end

local cache_file = vim.fn.stdpath("state") .. "/statusline_screen_px"
local function read_cache()
    local f = io.open(cache_file, "r")
    if f then
        local ok = apply_probe(f:read("*a"))
        f:close()
        return ok
    end
    return false
end
local function write_cache(px)
    local f = io.open(cache_file, "w")
    if f then
        f:write(px)
        f:close()
    end
end

do
    read_cache()
    -- PowerShell probe, Neovide only: a terminal nvim has no window of its
    -- own to measure, so spawning the probe there is pure waste. The probe
    -- script lives in scripts/screen-probe.ps1 (statically checkable and
    -- runnable on its own); it runs at VimEnter so the Neovide window
    -- certainly exists (during config load it has no handle yet); cache
    -- writes are gated on acceptance.
    if vim.g.neovide then
        local probe_script = vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "screen-probe.ps1")
        vim.api.nvim_create_autocmd("VimEnter", {
            callback = function()
                -- The probe result only changes on monitor / DPI / font
                -- changes, so a fresh cache (< 1h old) skips the spawn.
                local mtime = vim.fn.getftime(cache_file)
                if mtime > 0 and os.time() - mtime < 3600 then return end
                read_cache()
                -- The window is still at its initial size when VimEnter
                -- fires; wait for Neovide to finish laying it out first.
                vim.defer_fn(function()
                    vim.fn.jobstart({
                        "powershell",
                        "-NoProfile",
                        "-File",
                        probe_script,
                        "-NvimPid",
                        tostring(vim.fn.getpid()),
                    }, {
                        on_stdout = function(_, data)
                            local px = data[1]
                            if px and apply_probe(px) then write_cache(px) end
                        end,
                        on_exit = function(_, code)
                            if code ~= 0 then
                                vim.notify(
                                    "screen probe failed (exit "
                                        .. code
                                        .. "), narrow-layout threshold stays at default",
                                    vim.log.levels.WARN,
                                    { title = "statusline" }
                                )
                            end
                        end,
                    })
                end, 1500)
            end,
        })
    end
end

local MiniStatusline = require("mini.statusline")

-- One global statusline (mini.statusline's recommended setup).
vim.o.laststatus = 3

-- Per-severity diagnostic icons; colors come from the MiniStatuslineDiag*
-- groups in config/colors.lua (severity names must match its diag_fg keys).
-- vim.diagnostic.count() is nvim-cached, so this is cheap per refresh. Space
-- after each icon keeps the glyph and count apart (Nerd Font glyph metrics
-- can overflow the cell otherwise). Each fragment ends by switching back to
-- the Dim group: "%*" would restore the NORMAL background and break the
-- section's background.
local DIAG_SEVERITIES = {
    { vim.diagnostic.severity.ERROR, "Error", "󰅚" },
    { vim.diagnostic.severity.WARN, "Warn", "󰀪" },
    { vim.diagnostic.severity.INFO, "Info", "󰋽" },
    { vim.diagnostic.severity.HINT, "Hint", "󰌵" },
}

local function diagnostics()
    if MiniStatusline.is_truncated(60) or not vim.diagnostic.is_enabled({ bufnr = 0 }) then return "" end
    local counts = vim.diagnostic.count(0)
    local parts = {}
    for _, spec in ipairs(DIAG_SEVERITIES) do
        local n = counts[spec[1]] or 0
        if n > 0 then
            table.insert(
                parts,
                string.format("%%#MiniStatuslineDiag%s#%s %d%%#MiniStatuslineDim#", spec[2], spec[3], n)
            )
        end
    end
    if #parts == 0 then return "" end
    return "[" .. table.concat(parts, " ") .. "]"
end

-- Sorted for stable output: client order can vary between refreshes.
local function lsp_clients()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then return "" end
    local names = {}
    for _, client in ipairs(clients) do
        table.insert(names, client.name)
    end
    table.sort(names)
    return "󰰎 " .. table.concat(names, " ")
end

-- Working directory; hidden below the narrow threshold so narrow windows
-- keep only the mode, filename and the right side.
local function cwd()
    if MiniStatusline.is_truncated(narrow_threshold) then return "" end
    return vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
end

-- Branch from mini.git's buffer summary (empty outside git repos),
-- bracketed to match the diagnostics section.
local function git_branch()
    local git = MiniStatusline.section_git({ trunc_width = narrow_threshold })
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
    if vim.bo.buftype ~= "" then return "" end
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
-- Dim background, as a "file not in the cwd root" reminder. Below the narrow
-- threshold the directory part is dropped entirely (basename only). Overflow
-- is handled by the "%<" truncate point before this segment (see active()).
local function filename(short)
    if vim.bo.buftype == "terminal" then return "%t" end
    -- ":." = cwd-relative: files opened by absolute path still show their
    -- relative form; paths outside cwd stay absolute. Forward slashes keep
    -- the display consistent with fzf/mini.files-opened buffers.
    local f = vim.fn.fnamemodify(vim.fn.expand("%f"), ":."):gsub("\\", "/")
    local flags = (vim.bo.modified and " [+]" or "") .. (vim.bo.readonly and " [RO]" or "")
    if f == "" then return flags end
    local dir, base = f:match("^(.*[/\\])([^/\\]*)$")
    if dir then
        if short then return string.format("%%#MiniStatuslineFileBase#%s%%#MiniStatuslineDim#%s", base, flags) end
        return string.format("%s%%#MiniStatuslineFileBase#%s%%#MiniStatuslineDim#%s", dir, base, flags)
    end
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
            -- Below the narrow threshold: mode shrinks to 3 letters and
            -- cwd/git hide, so narrow windows keep mode + filename + the
            -- right side.
            local narrow = MiniStatusline.is_truncated(narrow_threshold)
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
                -- Truncate point: on overflow nvim cuts here (ellipsizing the
                -- filename) instead of shaving the leftmost mode block.
                "%<",
                { hl = "MiniStatuslineDim", strings = { filename(narrow) } },
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

-- Gradient follows the mode: rewrite the color groups on every mode change.
local colors = require("config.colors")
vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("statusline_mode_gradient", { clear = true }),
    pattern = "*:*",
    callback = function() colors.set_mode_gradient(vim.fn.mode()) end,
})
colors.set_mode_gradient("n")
