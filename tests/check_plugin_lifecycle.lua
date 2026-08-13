-- 生命周期检查：Mason setup 在启动时同步执行且可安全重复 require；
-- 测试 / 引导模式关闭自动安装检查，headless 运行绝不联网。

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- 1. 当前（NVIM_CONFIG_TEST=1）进程中的同步 setup。
check(package.loaded["mason"] ~= nil, "mason 必须在启动时加载")
check(vim.fn.exists(":Mason") == 2, ":Mason 必须在启动时已定义")
check(vim.fn.exists(":MasonToolsInstallSync") == 2, ":MasonToolsInstallSync 必须在启动时已定义")
check(vim.fn.exists(":MasonToolsInstall") == 2, ":MasonToolsInstall 必须在启动时已定义")

-- 2. 重复 require 模块必须是空操作。
local ok, err = pcall(require, "plugins.mason")
check(ok, "重复 require plugins.mason 必须成功：" .. tostring(err))

-- 3. mason-tool-installer 的 VimEnter autocmd（mti_start）必须恰好调用一次
--    run_on_start 后自我删除——且用的是本配置已应用的同步 setup，
--    因此执行的是测试模式行为（不安装检查）。
local mti = require("mason-tool-installer")
local calls = 0
local original_run_on_start = mti.run_on_start
mti.run_on_start = function() calls = calls + 1 end
vim.api.nvim_exec_autocmds("VimEnter", {})
vim.api.nvim_exec_autocmds("VimEnter", {})
check(calls == 1, "mti_start 必须恰好调用一次 run_on_start，实际 " .. tostring(calls))
mti.run_on_start = original_run_on_start

-- 3. 引导探针：NVIM_BOOTSTRAP=1 的全新 headless 实例必须在任何命令
--    执行前同步完成 setup。
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
check(result.code == 0, "引导探针失败：" .. tostring(result.stderr))

-- 4. 优先级加载器探针：全新实例中每个插件模块必须恰好 require 一次，
--    字母序遍历不得重复排队优先级模块（mini-core/mason/tokyonight）。
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
check(result2.code == 0, "优先级加载器探针失败：" .. tostring(result2.stderr))

if #failures > 0 then
    io.stderr:write("LIFECYCLE_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("LIFECYCLE_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
