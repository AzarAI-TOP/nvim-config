-- Editor options: display, indentation, search, editing, UI, and performance.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local platform = require("config.platform")

-- A Winget portable package may have updated the user PATH while Explorer/Neovide
-- still hold the old environment. Discover tools for the current process right
-- away; bootstrap-windows.ps1 also persists the directories for future shells.
if platform.is_windows then
    local package_root = vim.fs.joinpath(vim.env.LOCALAPPDATA or "", "Microsoft", "WinGet", "Packages")
    local winget_tools = {
        { exe = "fzf", glob = "junegunn.fzf_*/fzf.exe" },
        { exe = "lazygit", glob = "JesseDuffield.lazygit_*/lazygit.exe" },
    }
    for _, tool in ipairs(winget_tools) do
        if vim.fn.executable(tool.exe) == 0 then
            local matches = vim.fn.glob(vim.fs.joinpath(package_root, tool.glob), false, true)
            if #matches > 0 then vim.env.PATH = vim.fs.dirname(matches[1]) .. ";" .. (vim.env.PATH or "") end
        end
    end
end

-- A Windows nvim.exe launched from Git Bash inherits $SHELL=...bash.exe but keeps
-- cmd.exe's /s /c flags. Pin the native shell so :!, system(), filters, and :make
-- don't feed cmd flags into Bash.
if platform.is_windows then vim.opt.shell = vim.env.COMSPEC or "cmd.exe" end

-- ── Display ──
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"

-- ── Indentation ──
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- ── Search ──
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- ── Editing ──
vim.opt.wrap = false
vim.opt.mouse = "a"
-- WSL / SSH use explicit OSC52 copy while the unnamed register stays internal,
-- so plain `p` won't hang in terminals that forbid OSC52 reads.
-- Desktop Linux and Windows use native clipboard detection and enable unnamedplus.
if platform.is_remote then
    vim.g.clipboard = "osc52"
    vim.opt.clipboard = ""
else
    vim.opt.clipboard = "unnamedplus"
end
vim.opt.undofile = true
local undo_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "undo")
vim.fn.mkdir(undo_dir, "p")
vim.opt.undodir = undo_dir
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- ── UI ──
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.showmode = false
vim.opt.title = true

-- ── Folding ──
-- Treesitter-based folds; foldlevelstart=99 keeps every fold open by default.
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevelstart = 99

-- ── Performance ──
vim.opt.timeoutlen = 300
vim.opt.updatetime = 100
vim.opt.redrawtime = 1500

-- ── Completion ──
-- Popup shows without auto-selecting or auto-inserting the first item:
-- navigate with <C-n>/<C-p>, accept with <C-y> or <Tab>.
vim.opt.completeopt = "menuone,noselect,noinsert"
vim.opt.wildmode = "list:longest,full"
vim.opt.wildignore = { "*.o", "*.pyc", "*.class", "node_modules/*" }

-- ── Windows ──
vim.opt.splitright = true
vim.opt.splitbelow = true
