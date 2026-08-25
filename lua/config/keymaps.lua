-- Global keymaps. Every binding is registered via config.util.map, which also
-- records it in a registry so config.reload can delete and rebuild on reload.
--
-- <leader> prefix groups:
--   <leader>b  buffers
--   <leader>c  config
--   <leader>e  file explorer
--   <leader>f  find / files
--   <leader>l  language (formatting / LSP)
--   <leader>p  package management
--   <leader>s  splits
--   <leader>t  terminal
--   <leader>u  toggles
--   <leader>w  windows (forwarded to <C-w>)
--
-- LSP keymaps (<leader>ld, <leader>lh, etc.) are registered in config/lsp.lua:
-- vim.lsp.buf.* shows a native "no client attached" hint in buffers without a client.

local util = require("config.util")
local platform = require("config.platform")

-- ── Top level: files / session (no prefix) ──
util.map({ "n", "i" }, "<C-s>", "<Esc>:write<CR>", "Save file")
util.map("n", "<leader>q", ":quit<CR>", "Quit")
util.map("n", "<leader>Q", ":qa<CR>", "Quit all")
if not platform.is_windows and vim.fn.executable("sudo") == 1 then
    util.map("n", "<leader>W", ":write !sudo tee % > /dev/null<CR>", "Save as root")
end
if platform.is_remote then
    util.map({ "n", "x" }, "<leader>y", '"+y', "Copy to host clipboard")
    util.map("n", "<leader>Y", '"+Y', "Copy line to host clipboard")
end
util.map("n", "<leader>nh", ":nohlsearch<CR>", "Clear search highlight")

-- ── <leader>b — buffers ──
util.map("n", "<leader>bd", ":bdelete<CR>", "Delete buffer")
util.map("n", "<leader>bn", ":bnext<CR>", "Next buffer")
util.map("n", "<leader>bp", ":bprevious<CR>", "Previous buffer")

-- ── <leader>c — config ──
util.map("n", "<leader>ce", ":vsplit $MYVIMRC<CR>", "Edit config")
util.map("n", "<leader>cr", function() require("config.reload").reload() end, "Reload config")

-- ── <leader>l — language (formatting / LSP) ──
-- Format the current buffer (conform.nvim)
util.map("n", "<leader>lf", function()
    require("conform").format({ async = true, lsp_format = "fallback" }, function(err, did_edit)
        if err then
            vim.notify("Format failed: " .. tostring(err), vim.log.levels.ERROR)
        elseif did_edit then
            vim.notify("Formatted", vim.log.levels.INFO)
        else
            vim.notify("No changes needed or no formatter available", vim.log.levels.WARN)
        end
    end)
end, "Format file")

-- Diagnostic details (no LSP client required). Next/previous diagnostic jumps
-- are provided by mini.bracketed (]d / [d) — see plugins/mini.lua.
util.map("n", "<leader>lD", vim.diagnostic.open_float, "Diagnostic details")

-- ── <leader>e — file explorer ──
util.map("n", "<leader>e", function() require("mini.files").open() end, "File explorer")

-- ── <leader>f — find / search ──
util.map("n", "<Leader>ff", function() require("fzf-lua").files() end, "Find files")
util.map(
    "n",
    "<Leader>fc",
    function() require("fzf-lua").files({ cwd = vim.fn.stdpath("config") }) end,
    "Find config files"
)
util.map("n", "<Leader>fr", function() require("fzf-lua").registers() end, "Search registers")
util.map("n", "<Leader>fh", function() require("fzf-lua").helptags() end, "Search help")
util.map("n", "<Leader>ft", ":TodoFzfLua<CR>", "Find TODOs")
util.map(
    "n",
    "<Leader>fk",
    function() require("fzf-lua").keymaps({ modes = { "n" }, prompt = "Keymaps>" }) end,
    "Find keymaps"
)

-- TODO comment jumps
util.map("n", "]t", function() require("todo-comments").jump_next() end, "Next TODO")
util.map("n", "[t", function() require("todo-comments").jump_prev() end, "Previous TODO")

-- ── <leader>w — windows (forwarded to <C-w>) ──
util.map("n", "<leader>w", "<C-w>", "Window", { remap = true })

-- Direct window navigation (Alt+Arrows deliberately unmapped; <leader>w
-- covers window movement)
util.map("n", "<C-Up>", ":resize -2<CR>", "Decrease height")
util.map("n", "<C-Down>", ":resize +2<CR>", "Increase height")
util.map("n", "<C-Left>", ":vertical resize -2<CR>", "Decrease width")
util.map("n", "<C-Right>", ":vertical resize +2<CR>", "Increase width")

-- ── <leader>s — splits ──
util.map("n", "<leader>ss", ":split<CR>", "Split horizontal")
util.map("n", "<leader>sv", ":vsplit<CR>", "Split vertical")
util.map("n", "<leader>sc", ":close<CR>", "Close split")
util.map("n", "<leader>so", ":only<CR>", "Close other splits")

-- ── <leader>u — toggles ──
-- No paste-mode toggle: 'paste' is absent from the Neovim 0.12+ docs,
-- and bracketed paste handles pasting automatically.
util.map("n", "<leader>uw", ":set wrap!<CR>", "Toggle wrap")
-- Global toggle per the documented vim.lsp.inlay_hint pattern (0.12 runtime docs).
util.map("n", "<leader>ui", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    vim.notify(vim.lsp.inlay_hint.is_enabled() and "Inlay hints on" or "Inlay hints off", vim.log.levels.INFO)
end, "Toggle inlay hints")

-- ── <leader>p — package management ──
util.map("n", "<leader>pm", ":Mason<CR>", "Open Mason UI")
util.map("n", "<leader>pu", ":PackUpdate<CR>", "Update plugins")
util.map("n", "<leader>pU", ":MasonToolsUpdate<CR>", "Update Mason tools")
util.map("n", "<leader>pp", ":PackList<CR>", "List plugins")
util.map("n", "<leader>pi", ":MasonToolsInstallSync<CR>", "Install Mason tools")

-- ── Other direct keys ──
-- Search
util.map("n", "*", "*<C-o>", "Search word under cursor (no jump)")
util.map("n", "<Esc><Esc>", ":nohlsearch<CR>", "Clear highlight (double Esc)")

-- Hop (character jump): f = in-line search (current line only), F = whole-window search
util.map("n", "f", function() require("hop").hint_char1({ current_line_only = true }) end, "Hop char in line")
util.map("n", "F", function() require("hop").hint_char1() end, "Hop char in window")

-- Scroll and center
util.map("n", "<C-d>", "<C-d>zz", "Scroll half page down and center")
util.map("n", "<C-u>", "<C-u>zz", "Scroll half page up and center")
util.map("n", "n", "nzzzv", "Next result and center")
util.map("n", "N", "Nzzzv", "Previous result and center")

-- Comments (mini.comment)
util.map("n", "<C-/>", "gcc", "Toggle comment", { remap = true })
util.map("v", "<C-/>", "gc", "Toggle comment", { remap = true })

-- ── <leader>t — terminal (toggleterm.nvim) ──
-- Each binding owns a fixed terminal id, so toggling always reopens the same
-- terminal (Terminal:new returns the existing terminal for a taken id, which
-- also keeps the bindings working after a :ConfigReload). Plain terminals use
-- the configured shell (cmd.exe on Windows); lazygit / ipython run their own
-- command. <F2> is a direct alias for the floating toggle, replacing the old
-- ":split | terminal" mappings. In terminal mode, <F2> toggles the terminal
-- under the cursor instead — identify() reads the id from the buffer-name tag
-- the plugin writes at spawn time; untagged :terminal buffers fall back to
-- the float.
local function terminal_toggle(id, direction, cmd)
    return function()
        require("toggleterm.terminal").Terminal:new({ id = id, direction = direction, cmd = cmd }):toggle()
    end
end

-- One symbol for the float tuple so <leader>tf, <F2>, and the terminal-mode
-- fallback below cannot drift apart.
local toggle_float = terminal_toggle(5, "float")

local function toggle_current_terminal()
    local term_mod = require("toggleterm.terminal")
    local _, term = term_mod.identify()
    if term then
        term:toggle()
    else
        toggle_float()
    end
end

util.map("n", "<leader>th", terminal_toggle(1, "horizontal"), "Toggle horizontal terminal")
util.map("n", "<leader>tv", terminal_toggle(2, "vertical"), "Toggle vertical terminal")
util.map("n", "<leader>tg", terminal_toggle(3, "horizontal", "lazygit"), "Toggle lazygit")
util.map("n", "<leader>tp", terminal_toggle(4, "horizontal", "ipython"), "Toggle ipython")
util.map("n", "<leader>tf", toggle_float, "Toggle floating terminal")
util.map("n", "<F2>", toggle_float, "Toggle floating terminal")
util.map("t", "<F2>", toggle_current_terminal, "Toggle current terminal")
util.map("t", "<Esc><Esc>", "<C-\\><C-n>", "Exit terminal's insert mode", { noremap = true })
