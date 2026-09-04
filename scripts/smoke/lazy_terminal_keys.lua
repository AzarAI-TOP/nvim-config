-- Headless acceptance: toggleterm factory spawn and the bento `;` stub logic.
-- Run from the repo root (dev junction):
--   NVIM_APPNAME=nvim-config nvim --headless -S scripts/smoke/lazy_terminal_keys.lua
-- (feedkeys with execute=false only queues into typeahead, which a headless
-- -S script never consumes before qa! — so the stub is invoked directly via
-- its maparg callback instead. The queued replay fires in real sessions.)
-- Note: the spawned cmd.exe inherits stdout; run with output redirected to a
-- file, not through a pipe (an orphaned cmd.exe holding the pipe deadlocks it).

local term = require("plugins.toggleterm")
term.toggle(1, "horizontal")()
vim.wait(600)
print("toggleterm spawned: " .. tostring(type(package.loaded["toggleterm.terminal"]) == "table"))

print("; stub mapped: " .. tostring(vim.fn.maparg(";", "n") ~= ""))
local stub = vim.fn.maparg(";", "n", false, true)
stub.callback()
vim.wait(1000)
print("bento loaded via stub: " .. tostring(package.loaded["bento"] ~= nil))
local after = vim.fn.maparg(";", "n", false, true)
print("; now owned by: " .. tostring(type(after) == "table" and (after.desc or "lua mapping") or after))
vim.cmd("qa!")
