-- Headless acceptance: :Mason command stub replay + :ConfigReload interaction
-- (config.lazy must survive the package.loaded sweep and stay functional).
-- Run from the repo root (dev junction):
--   NVIM_APPNAME=nvim-config nvim --headless -S scripts/smoke/lazy_cmds_reload.lua

local cmds = vim.api.nvim_get_commands({})
print("Mason stub defined: " .. tostring(cmds.Mason ~= nil))
print("MasonToolsUpdate stub defined: " .. tostring(cmds.MasonToolsUpdate ~= nil))

vim.cmd("Mason")
vim.wait(200)
print("mason loaded via cmd: " .. tostring(package.loaded["mason"] ~= nil))
print("real Mason defined: " .. tostring(vim.api.nvim_get_commands({}).Mason ~= nil))

require("config.reload").reload()
vim.wait(200)
print("post-reload fzf trigger: " .. tostring(type(require("fzf-lua")) == "table"))
print("post-reload Mason defined: " .. tostring(vim.api.nvim_get_commands({}).Mason ~= nil))
print("post-reload f mapped: " .. tostring(vim.fn.maparg("f", "n") ~= ""))
print("post-reload <leader>th mapped: " .. tostring(vim.fn.maparg("<leader>th", "n") ~= ""))
print("post-reload jump2d defer idempotent: " .. tostring(type(require("mini.jump2d").start) == "function"))
vim.cmd("qa!")
