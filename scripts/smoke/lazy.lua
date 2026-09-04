-- Headless acceptance: lazy-loading stubs, preload triggers, load_all.
-- Run from the repo root (dev junction):
--   NVIM_APPNAME=nvim-config nvim --headless -S scripts/smoke/lazy.lua
-- (vim.pack.get() reports the installed/lock view, not "already added", so
-- deferred state is asserted via package.loaded instead.)

print("fzf stub present: " .. tostring(package.preload["fzf-lua"] ~= nil))
print("conform not loaded: " .. tostring(package.loaded["conform"] == nil))
print("mason not loaded: " .. tostring(package.loaded["mason"] == nil))

local fzf = require("fzf-lua")
print("fzf-lua require ok: " .. tostring(type(fzf) == "table"))
print("fzf-lua.utils ok: " .. tostring(type(require("fzf-lua.utils")) == "table"))
print("jump2d ok: " .. tostring(type(require("mini.jump2d").start) == "function"))
print("conform ok: " .. tostring(type(require("conform").format) == "function"))
print("mini.sessions ok: " .. tostring(type(require("mini.sessions").select) == "function"))
print("toggleterm mod ok: " .. tostring(type(require("toggleterm.terminal").Terminal) == "table"))

require("config.lazy").load_all()
print("mason loaded: " .. tostring(package.loaded["mason"] ~= nil))
print("bento loaded: " .. tostring(package.loaded["bento"] ~= nil))
print("stubs cleared: " .. tostring(package.preload["fzf-lua"] == nil))
vim.cmd("qa!")
