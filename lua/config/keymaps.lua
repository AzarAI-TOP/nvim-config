-- Global keymaps. Every binding is registered via config.util.map, which also
-- records it in a registry so config.reload can delete and rebuild on reload.
--
-- <leader> prefix groups:
--   <leader>b  buffers
--   <leader>c  config
--   <leader>e  file explorer
--   <leader>f  find / search / grep
--   <leader>l  language (formatting / LSP)
--   <leader>p  package management
--   <leader>s  splits
--   <leader>S  sessions
--   <leader>t  terminal
--   <leader>u  toggles
--
-- LSP keymaps (<leader>ld, <leader>lh, etc.) are registered in config/lsp.lua:
-- vim.lsp.buf.* shows a native "no client attached" hint in buffers without a client.

local util = require("config.util")

-- ── Top level: files / session (no prefix) ──
-- Insert-mode save stays in Insert mode: <C-o> runs one command and returns.
util.map("n", "<C-s>", ":write<CR>", "Save file")
util.map("i", "<C-s>", "<C-o>:write<CR>", "Save file")
util.map("n", "<leader>q", ":quit<CR>", "Quit")
util.map("n", "<leader>Q", ":qa<CR>", "Quit all")

-- ── <leader>b — buffers ──
util.map("n", "<leader>bd", ":bdelete<CR>", "Delete buffer")
util.map("n", "<leader>bn", ":bnext<CR>", "Next buffer")
util.map("n", "<leader>bp", ":bprevious<CR>", "Previous buffer")

-- ── <leader>c — config ──
util.map("n", "<leader>ce", ":vsplit $MYVIMRC<CR>", "Edit config")
util.map("n", "<leader>cr", function() require("config.reload").reload() end, "Reload config")

-- ── <leader>S — sessions ──
-- Global sessions keep project directories clean; restored sessions
-- auto-update on exit (autowrite), so Ss is only for new snapshots.
util.map("n", "<leader>Ss", function()
    local s = require("mini.sessions")
    local name = vim.fn.input("Session name: ", vim.fn.fnamemodify(vim.fn.getcwd(), ":t"))
    if name == "" then
        vim.notify("Session name is required", vim.log.levels.WARN, { title = "sessions" })
        return
    end
    s.write(name)
end, "Save session")
util.map("n", "<leader>Sl", function() require("mini.sessions").select() end, "Load session")
util.map("n", "<leader>Sd", function() require("mini.sessions").select("delete") end, "Delete session")

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
util.map("n", "<leader>ff", function() require("fzf-lua").files() end, "Find files")
util.map(
    "n",
    "<leader>fc",
    function() require("fzf-lua").files({ cwd = vim.fn.stdpath("config") }) end,
    "Find config files"
)
util.map("n", "<leader>fr", function() require("fzf-lua").registers() end, "Search registers")
util.map("n", "<leader>fh", function() require("fzf-lua").helptags() end, "Search help")
util.map("n", "<leader>ft", ":TodoFzfLua<CR>", "Find TODOs")
util.map(
    "n",
    "<leader>fk",
    -- Default modes cover n/i/c/v/t, so insert/terminal bindings show too
    function() require("fzf-lua").keymaps({ prompt = "Keymaps> " }) end,
    "Find keymaps"
)
-- Project-wide grep (ripgrep). In the picker, <C-q> sends matches to the
-- quickfix list, where :cdo runs an Ex command on every hit and ]q/[q
-- (mini.bracketed) jumps between them.
util.map("n", "<leader>fg", function() require("fzf-lua").grep() end, "Grep project")
util.map("n", "<leader>fG", function() require("fzf-lua").live_grep() end, "Live grep")
util.map("n", "<leader>fW", function() require("fzf-lua").grep_cword() end, "Grep word under cursor")

-- Notification history as an fzf picker: fuzzy search over one-line entries
-- (colored level + timestamp + collapsed message), preview pane shows the
-- full message. opts.preview is the fzf-lua pattern also used by registers.
local function notifications_picker()
    local entries = require("mini.notify").get_all()
    if #entries == 0 then
        vim.notify("No notifications yet", vim.log.levels.INFO)
        return
    end
    -- Newest first.
    table.sort(entries, function(a, b) return a.ts_update > b.ts_update end)

    local ansi = require("fzf-lua.utils").ansi_codes
    local level_color = {
        ERROR = ansi.red,
        WARN = ansi.yellow,
        INFO = ansi.green,
        DEBUG = ansi.cyan,
        TRACE = ansi.magenta,
    }

    local items, previews = {}, {}
    for i, n in ipairs(entries) do
        -- Millisecond precision keeps display lines unique: the preview
        -- matches by line, and same-second identical collapses would
        -- otherwise preview the wrong full message.
        local ms = string.format(".%03d", math.floor(n.ts_update * 1000) % 1000)
        local ts = vim.fn.strftime("%H:%M:%S", math.floor(n.ts_update)) .. ms
        local color = level_color[n.level] or ansi.white
        items[i] = color(string.format("[%s]", n.level)) .. " " .. ts .. " " .. n.msg:gsub("[\r\n]", " ")
        previews[i] = string.format("[%s] %s\n\n%s", n.level, ts, n.msg)
    end

    require("fzf-lua").fzf_exec(items, {
        prompt = "Notifications> ",
        preview = function(args)
            local sel = args[1]
            for i, item in ipairs(items) do
                if item == sel then return previews[i] end
            end
            return sel
        end,
    })
end
util.map("n", "<leader>fn", notifications_picker, "Show notifications")

-- TODO comment jumps
util.map("n", "]t", function() require("todo-comments").jump_next() end, "Next TODO")
util.map("n", "[t", function() require("todo-comments").jump_prev() end, "Previous TODO")

-- Alt+Arrows deliberately unmapped
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
-- Completion autotrigger on/off for every attached client; <C-Space> keeps
-- working either way (config/lsp.lua holds the state and the loop).
util.map("n", "<leader>uc", function() require("config.lsp").toggle_autotrigger() end, "Toggle completion autotrigger")

-- ── <leader>p — package management ──
util.map("n", "<leader>pm", ":Mason<CR>", "Open Mason UI")
util.map("n", "<leader>pu", ":PackUpdate<CR>", "Update plugins")
util.map("n", "<leader>pU", ":MasonToolsUpdate<CR>", "Update Mason tools")
util.map("n", "<leader>pl", ":PackList<CR>", "List plugins")
util.map("n", "<leader>pi", ":MasonToolsInstallSync<CR>", "Install Mason tools")

-- ── Other direct keys ──
-- Search
util.map("n", "*", "*<C-o>", "Search word under cursor (no jump)")
util.map("n", "<Esc><Esc>", ":nohlsearch<CR>", "Clear highlight (double Esc)")

-- Hop (character jump): f = in-line search (current line only), F = whole-window search.
-- Mode "v" covers visual AND select mode: jumping there extends the selection
-- instead of moving the cursor.
util.map({ "n", "v" }, "f", function() require("hop").hint_char1({ current_line_only = true }) end, "Hop char in line")
util.map({ "n", "v" }, "F", function() require("hop").hint_char1() end, "Hop char in window")

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
util.map("i", "<F2>", toggle_float, "Toggle floating terminal")
util.map("t", "<F2>", toggle_current_terminal, "Toggle current terminal")
util.map("t", "<Esc><Esc>", "<C-\\><C-n>", "Exit terminal's insert mode", { noremap = true })
