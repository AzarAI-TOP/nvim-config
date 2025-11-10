-- Nvim Options
local opt = vim.opt

-- Leader
vim.g.mapleader = " "
vim.g.maplocalleader = ","


-- Basic
opt.clipboard   = vim.env.SSH_CONNECTION and "" or "unnamedplus" -- Sync with system clipboard
opt.confirm     = true                                           -- Confirm to save changes before exiting modified buffer
opt.mouse       = "a"                                            -- Enable mouse mode
opt.number      = true                                           -- Print line number
opt.wrap        = false                                          -- Disable line wrap
opt.cursorline  = true                                           -- Enable highlighting of the current line

-- Indent
opt.autoindent  = true
opt.shiftround  = true -- Round indent
opt.shiftwidth  = 2    -- Size of an indent
opt.expandtab   = true -- Use spaces instead of tabs
opt.tabstop     = 2    -- Number of spaces tabs count for

-- Status Line
opt.showmode    = false
vim.o.cmdheight = 0


-- Provider
vim.g.loaded_perl_provider = 0
