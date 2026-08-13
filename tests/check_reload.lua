-- Real hot-reload of the core config layer: a fresh instance mutates runtime
-- state the way a user session would, runs config.reload(), and must get every
-- mutated surface restored while plugin state survives untouched.

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- <leader>cr must invoke the reload module (not a bare :source).
local cr = vim.fn.maparg("<leader>cr", "n", false, true)
check(type(cr.callback) == "function", "<leader>cr must use a Lua callback (real reload)")

-- Subprocess probe: full config loads, then the probe mutates + reloads.
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
    "-- idempotency: a second reload must be a clean no-op",
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
check(result.code == 0, "reload probe failed: " .. tostring(result.stderr))
check(
    not tostring(result.stderr):find("重载失败", 1, true),
    "reload must not report module failures: " .. tostring(result.stderr)
)

if #failures > 0 then
    io.stderr:write("RELOAD_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("RELOAD_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
