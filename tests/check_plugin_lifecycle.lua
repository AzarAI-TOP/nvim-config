-- Lifecycle checks: Mason setup runs synchronously at startup and is safe to
-- re-require; test/bootstrap modes disable the automatic install check so
-- headless runs never hit the network.

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- 1. Synchronous setup in this (NVIM_CONFIG_TEST=1) process.
check(package.loaded["mason"] ~= nil, "mason must be loaded at startup")
check(vim.fn.exists(":Mason") == 2, ":Mason must be defined at startup")
check(vim.fn.exists(":MasonToolsInstallSync") == 2, ":MasonToolsInstallSync must be defined at startup")
check(vim.fn.exists(":MasonToolsInstall") == 2, ":MasonToolsInstall must be defined at startup")

-- 2. Re-requiring the module must be a no-op.
local ok, err = pcall(require, "plugins.mason")
check(ok, "re-requiring plugins.mason must succeed: " .. tostring(err))

-- 3. mason-tool-installer's VimEnter autocmd (mti_start) must invoke
--    run_on_start exactly once, then delete itself — with our synchronous
--    setup already applied, so the configured test-mode behavior (no
--    install check) is what runs.
local mti = require("mason-tool-installer")
local calls = 0
local original_run_on_start = mti.run_on_start
mti.run_on_start = function() calls = calls + 1 end
vim.api.nvim_exec_autocmds("VimEnter", {})
vim.api.nvim_exec_autocmds("VimEnter", {})
check(calls == 1, "mti_start must invoke run_on_start exactly once, got " .. tostring(calls))
mti.run_on_start = original_run_on_start

-- 3. Bootstrap probe: a fresh headless instance with NVIM_BOOTSTRAP=1 must
--    complete setup synchronously before any command runs.
local probe = table.concat({
    "local ok, err = pcall(function()",
    "require('plugins.mason')",
    "assert(package.loaded['mason'] ~= nil, 'mason not loaded synchronously')",
    "assert(vim.fn.exists(':Mason') == 2, ':Mason missing')",
    "assert(vim.fn.exists(':MasonToolsInstallSync') == 2, ':MasonToolsInstallSync missing')",
    "end)",
    "if not ok then io.stderr:write('BOOTSTRAP_PROBE_FAILED: ' .. tostring(err) .. '\\n'); vim.cmd('cquit 1') end",
    "vim.cmd('qa!')",
}, "\n")
local probe_file = vim.fn.tempname() .. ".lua"
vim.fn.writefile(vim.split(probe, "\n", { plain = true }), probe_file)
local env = vim.fn.environ()
env["NVIM_BOOTSTRAP"] = "1"
env["NVIM_CONFIG_TEST"] = "1"
local result = vim.system(
    { vim.fn.exepath("nvim"), "--headless", "-n", "+luafile " .. probe_file },
    { env = env, text = true }
)
    :wait(60000)
os.remove(probe_file)
check(result.code == 0, "bootstrap probe failed: " .. tostring(result.stderr))

-- 4. Priority loader probe: each plugin module must be required exactly once
--    in a fresh instance. The alphabetical pass must not re-queue priority
--    modules (mini-core/mason/tokyonight).
local probe = table.concat({
    "local counts = _G.__loader_counts",
    "for _, name in ipairs({ 'plugins.mini-core', 'plugins.mason', 'plugins.tokyonight' }) do",
    "  assert(counts[name] == 1, name .. ' required ' .. tostring(counts[name]) .. ' times')",
    "end",
    "io.stdout:write('PRIORITY_LOADER_OK\\n')",
    "vim.cmd('qa!')",
}, "\n")
local probe_file = vim.fn.tempname() .. ".lua"
vim.fn.writefile(vim.split(probe, "\n", { plain = true }), probe_file)
local preload = table.concat({
    "local counts = {}",
    "_G.__loader_counts = counts",
    "local orig = require",
    "_G.require = function(name)",
    "  counts[name] = (counts[name] or 0) + 1",
    "  return orig(name)",
    "end",
}, "\n")
local preload_file = vim.fn.tempname() .. ".lua"
vim.fn.writefile(vim.split(preload, "\n", { plain = true }), preload_file)
local env = vim.fn.environ()
env["NVIM_CONFIG_TEST"] = "1"
env["NVIM_BOOTSTRAP"] = nil
local result2 = vim.system({
    vim.fn.exepath("nvim"),
    "--headless",
    "-n",
    "--cmd",
    "luafile " .. preload_file,
    "+luafile " .. probe_file,
}, { env = env, text = true }):wait(60000)
os.remove(probe_file)
os.remove(preload_file)
check(result2.code == 0, "priority loader probe failed: " .. tostring(result2.stderr))

if #failures > 0 then
    io.stderr:write("LIFECYCLE_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("LIFECYCLE_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
