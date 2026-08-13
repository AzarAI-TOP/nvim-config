-- 核心配置层的真实热重载：全新实例像用户会话一样篡改运行时状态，
-- 再执行 config.reload()，所有被篡改的表面必须恢复，
-- 而插件状态原样保留。

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- <leader>cr 必须调用 reload 模块（而非裸 :source）。
local cr = vim.fn.maparg("<leader>cr", "n", false, true)
check(type(cr.callback) == "function", "<leader>cr 必须使用 Lua 回调（真实重载）")

-- 子进程探针：完整加载配置后，探针篡改状态并重载。
local probe = table.concat({
    "vim.opt.number = false",
    "vim.keymap.del('n', '<leader>bd')",
    "pcall(vim.api.nvim_del_user_command, 'PackUpdate')",
    "assert(vim.fn.maparg('<leader>bd', 'n') == '', 'setup: keymap deletion must take effect')",
    "require('config.reload').reload()",
    "assert(vim.opt.number:get() == true, 'options must be restored by reload')",
    "assert(vim.fn.maparg('<leader>bd', 'n') ~= '', 'keymaps must be restored by reload')",
    "assert(vim.fn.exists(':PackUpdate') == 2, 'user commands must be restored by reload')",
    "assert(package.loaded['mason'] ~= nil, 'plugin modules must not be cleared')",
    "assert(vim.fn.exists(':Mason') == 2, 'plugin commands must survive reload')",
    "assert(vim.g.colors_name == 'tokyonight-moon', 'colorscheme must survive reload')",
    "assert(type(require('mini.clue').config.triggers) == 'table', 'mini.clue must stay configured')",
    "-- 幂等性：第二次重载必须是干净的空操作",
    "require('config.reload').reload()",
    "assert(vim.opt.number:get() == true, 'options must survive a second reload')",
    "assert(vim.fn.maparg('<leader>bd', 'n') ~= '', 'keymaps must survive a second reload')",
    "assert(vim.fn.exists(':PackUpdate') == 2, 'commands must survive a second reload')",
    "io.stdout:write('RELOAD_CHECK_OK\\n')",
    "vim.cmd('qa!')",
}, "\n")
local probe_file = vim.fn.tempname() .. ".lua"
vim.fn.writefile(vim.split(probe, "\n", { plain = true }), probe_file)
local env = vim.fn.environ()
env["NVIM_CONFIG_TEST"] = "1"
env["NVIM_BOOTSTRAP"] = nil
local result = vim.system(
    { vim.fn.exepath("nvim"), "--headless", "-n", "+luafile " .. probe_file },
    { env = env, text = true }
)
    :wait(60000)
os.remove(probe_file)
check(result.code == 0, "重载探针失败：" .. tostring(result.stderr))
check(
    not tostring(result.stderr):find("重载失败", 1, true),
    "重载不得报告模块失败：" .. tostring(result.stderr)
)

if #failures > 0 then
    io.stderr:write("RELOAD_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("RELOAD_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
