-- 编辑器选项：显示、缩进、搜索、编辑、界面与性能。

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local platform = require("config.platform")

-- Winget 便携包可能已更新用户 PATH，而 Explorer/Neovide 仍持有旧环境。
-- 立即为当前进程发现 fzf；bootstrap-windows.ps1 也会为未来 shell 持久化目录。
if platform.is_windows and vim.fn.executable("fzf") == 0 then
    local package_root = vim.fs.joinpath(vim.env.LOCALAPPDATA or "", "Microsoft", "WinGet", "Packages")
    local matches = vim.fn.glob(vim.fs.joinpath(package_root, "junegunn.fzf_*", "fzf.exe"), false, true)
    if #matches > 0 then
        local fzf_dir = vim.fs.dirname(matches[1])
        vim.env.PATH = fzf_dir .. ";" .. (vim.env.PATH or "")
    end
end

-- 从 Git Bash 启动的 Windows nvim.exe 会继承 $SHELL=...bash.exe，
-- 却保留 cmd.exe 的 /s /c 标志。固定为原生 shell，避免 :!、system()、
-- 过滤器和 :make 把 cmd 标志送进 Bash。
if platform.is_windows then vim.opt.shell = vim.env.COMSPEC or "cmd.exe" end

-- ── 显示 ──
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"

-- ── 缩进 ──
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.autoindent = true

-- ── 搜索 ──
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- ── 编辑 ──
vim.opt.wrap = false
vim.opt.mouse = "a"
-- WSL / SSH 显式走 OSC52 复制，无名寄存器保持内部，
-- 普通 `p` 不会在禁止 OSC52 读取的终端里卡住。
-- 桌面 Linux 与 Windows 使用原生剪贴板发现并启用 unnamedplus。
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

-- ── 界面 ──
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.showmode = false
vim.opt.title = true

-- ── 性能 ──
vim.opt.timeoutlen = 300
vim.opt.updatetime = 100
vim.opt.redrawtime = 1500

-- ── 补全 ──
vim.opt.wildmode = "list:longest,full"
vim.opt.wildignore = { "*.o", "*.pyc", "*.class", "node_modules/*" }

-- ── 历史 ──
vim.opt.history = 1000
vim.opt.undolevels = 1000

-- ── 窗口 ──
vim.opt.splitright = true
vim.opt.splitbelow = true
