-- ~/.config/nvim/lua/config/options.lua
-- Editor options

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local platform = require("config.platform")

-- Winget portable packages can update the user PATH while Explorer/Neovide
-- still holds an older environment. Discover fzf for this process immediately;
-- bootstrap-windows.ps1 also persists the directory for future shells.
if platform.is_windows and vim.fn.executable("fzf") == 0 then
    local package_root = vim.fs.joinpath(vim.env.LOCALAPPDATA or "", "Microsoft", "WinGet", "Packages")
    local matches = vim.fn.glob(vim.fs.joinpath(package_root, "junegunn.fzf_*", "fzf.exe"), false, true)
    if #matches > 0 then
        local fzf_dir = vim.fs.dirname(matches[1])
        vim.env.PATH = fzf_dir .. ";" .. (vim.env.PATH or "")
    end
end

-- A Windows nvim.exe launched from Git Bash inherits $SHELL=...bash.exe while
-- retaining cmd.exe's /s /c flags. Pin the matching native shell so :!,
-- system(), filters, and :make do not receive cmd flags through Bash.
if platform.is_windows then vim.opt.shell = vim.env.COMSPEC or "cmd.exe" end

-- Display
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"

-- Indentation
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.autoindent = true

-- Search
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Editing
vim.opt.wrap = false
vim.opt.mouse = "a"
-- WSL and SSH copy explicitly through OSC52. Keep their unnamed register
-- internal so ordinary `p` never waits for terminals that forbid OSC52 reads.
-- Desktop Linux and Windows use native provider discovery and unnamedplus.
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

-- UI
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.showmode = false
vim.opt.title = true

-- Performance
vim.opt.timeoutlen = 300
vim.opt.updatetime = 100
vim.opt.redrawtime = 1500

-- Completion
vim.opt.wildmode = "list:longest,full"
vim.opt.wildignore = { "*.o", "*.pyc", "*.class", "node_modules/*" }

-- History
vim.opt.history = 1000
vim.opt.undolevels = 1000

-- Windows
vim.opt.splitright = true
vim.opt.splitbelow = true
