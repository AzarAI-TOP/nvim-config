-- Editor options: display, indentation, search, editing, UI, and performance.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- No remote-plugin hosts in use; disabling skips host lookup and checkhealth noise.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

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
-- System clipboard via $SHELL's environment: unnamedplus ties yank/paste to the
-- X11 (xclip) / Wayland (wl-clipboard) clipboard; bootstrap-ubuntu.sh installs xclip.
vim.opt.clipboard = "unnamedplus"
vim.opt.undofile = true
local undo_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "undo")
vim.fn.mkdir(undo_dir, "p")
vim.opt.undodir = undo_dir
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- ── Sessions ──
-- Pinned explicitly: `options` (global options + mappings) must never leak
-- into session files — loading an old session must not resurrect mappings
-- deleted from the config since — and `terminal` is dropped because
-- toggleterm owns its terminal lifecycle (restored terminal jobs are dead).
-- Neovim 0.12's default already omits `options`; this pins the whole set
-- against future default changes or plugin writes.
vim.opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize"

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

-- ── Split placement ──
vim.opt.splitright = true
vim.opt.splitbelow = true
