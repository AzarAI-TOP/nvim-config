-- Editor options: display, indentation, search, editing, UI, and performance.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- A Winget portable package may have updated the user PATH while Explorer/Neovide
-- still hold the old environment. Discover tools for the current process right
-- away; bootstrap-windows.ps1 also persists the directories for future shells.
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

-- A Windows nvim.exe launched from Git Bash inherits $SHELL=...bash.exe but keeps
-- cmd.exe's /s /c flags. Pin the native shell so :!, system(), filters, and :make
-- don't feed cmd flags into Bash.
vim.opt.shell = vim.env.COMSPEC or "cmd.exe"

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
-- Native :grep uses ripgrep (vimgrep output for quickfix compatibility)
vim.opt.grepprg = "rg --vimgrep"

-- ── Editing ──
-- Quitting or deleting a modified buffer asks (y=save / n=discard / c=cancel)
-- instead of failing with E37/E89; covers manual :q/:bd too.
vim.opt.confirm = true
vim.opt.wrap = false
vim.opt.mouse = "a"
-- Native Windows clipboard: unnamedplus ties yank/paste to the system clipboard.
vim.opt.clipboard = "unnamedplus"
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
-- navigate with <C-n>/<C-p>, accept with <C-y>.
vim.opt.completeopt = "menuone,noselect,noinsert"
vim.opt.wildmode = "list:longest,full"
vim.opt.wildignore = { "*.o", "*.pyc", "*.class", "node_modules/*" }

-- ── Windows ──
vim.opt.splitright = true
vim.opt.splitbelow = true
