-- Behavioral lifecycle checks for plugin loading and Mason setup deferral.
--
-- Under NVIM_CONFIG_TEST=1 the config defers Mason setup exactly like normal
-- startup: plugins/mason.lua's pack declaration loads during startup, but the
-- registry-heavy `require("mason").setup()` chain must NOT be pulled in until
-- after the interactive startup boundary. The only startup work is a cheap,
-- explicit PATH prepend of stdpath('data')/mason/bin (no mason module is
-- loaded for it). Setup itself runs once via a vim.schedule() continuation
-- from the VimEnter callback, which also deletes mason-tool-installer's own
-- `mti_start` VimEnter autocmd so its DEFAULT-settings run_on_start (a
-- registry refresh) can never fire. A pre-VimEnter :Mason* command
-- (CmdUndefined) still initializes synchronously so Neovim retries the
-- now-defined command. Bootstrap mode (NVIM_BOOTSTRAP=1) must instead set up
-- synchronously during startup.
--
-- Five fresh-subprocess probes verify the modes from inside clean headless
-- instances:
--   1. NVIM_BOOTSTRAP=1 asserts eager synchronous setup.
--   2. no bootstrap: the genuinely undefined, noninteractive :MasonLog
--      invoked pre-VimEnter fires CmdUndefined, initializes Mason, and the
--      command is retried without recursion (auto-check NOT arranged in this
--      ephemeral process — that is the VimEnter continuation's job).
--   3. injected setup failure: setup attempts exactly once, the recorded
--      failure is rethrown by every later trigger (CmdUndefined, scheduled
--      continuation) without rerunning, and no auto-check is arranged.
--   4. natural empty startup: VimEnter fires, mti_start is neutralized,
--      the scheduled continuation runs setup exactly once and invokes the
--      configured mason-tool-installer run_on_start() exactly once.
--
-- All assertions observe module/setup state, autocmd wiring, and PATH —
-- never source text.

local failures = {}

local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

local function path_sep() return vim.loop.os_uname().sysname == "Windows_NT" and ";" or ":" end

local function path_count_bin(entry)
    local ci = path_sep() == ";"
    local target = ci and entry:lower() or entry
    local n = 0
    for part in (vim.env.PATH or ""):gmatch("[^" .. path_sep() .. "]+") do
        local p = ci and part:lower() or part
        if p == target then n = n + 1 end
    end
    return n
end

local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin")

local mason_mod = require("plugins.mason")

-- 1. Normal (deferred) startup state: infrastructure module loaded, Mason
--    registry machinery not loaded, real :Mason command not yet defined, and
--    the mason bin dir already on PATH (the only startup cost).
check(
    package.loaded["mason"] == nil,
    "normal startup must not load mason (deferred); got " .. tostring(package.loaded["mason"])
)
check(
    type(mason_mod) == "table" and type(mason_mod.ensure_setup) == "function",
    "plugins.mason must expose an idempotent ensure_setup()"
)
check(
    type(mason_mod) == "table" and type(mason_mod.state) == "table" and mason_mod.state.status == "not_started",
    "Mason setup must not have run during normal startup"
)
check(vim.fn.exists(":Mason") ~= 2, ":Mason must not be defined before deferred setup runs")
check(vim.fn.exists(":MasonInstall") ~= 2, ":MasonInstall must not be defined before deferred setup runs")
check(vim.fn.exists(":MasonToolsInstall") == 2, "MasonToolsInstall must exist from packadd")
check(vim.fn.exists(":MasonToolsInstallSync") == 2, "MasonToolsInstallSync must exist from packadd")
check(path_count_bin(mason_bin) >= 1, "PATH must contain the mason bin dir before any setup")

-- Trigger wiring exists (events registered by plugins/mason.lua).
local group = vim.api.nvim_get_autocmds({ group = "mason_deferred_setup" })
local events = {}
for _, autocmd in ipairs(group) do
    events[autocmd.event] = true
end
check(events["VimEnter"], "VimEnter trigger must be registered")
check(events["CmdUndefined"], "CmdUndefined trigger must be registered")
check(
    not events["BufReadPre"],
    "BufReadPre trigger must NOT be registered (setup must stay after the startup boundary)"
)

-- mason-tool-installer ships its own VimEnter autocmd (`mti_start`) which
-- calls run_on_start() with DEFAULT settings (registry refresh). Our VimEnter
-- callback must have an earlier autocmd id, otherwise an empty startup runs
-- the plugin's defaults before our configured options are applied — and the
-- mti_start deletion inside our callback only works when we run first.
local deferred_vimenter = vim.api.nvim_get_autocmds({ group = "mason_deferred_setup", event = "VimEnter" })
local installer_vimenter = vim.api.nvim_get_autocmds({ group = "mti_start", event = "VimEnter" })
check(#deferred_vimenter == 1, "exactly one deferred Mason VimEnter callback must exist")
check(#installer_vimenter == 1, "mason-tool-installer VimEnter callback must exist pre-VimEnter")
if #deferred_vimenter == 1 and #installer_vimenter == 1 then
    check(
        deferred_vimenter[1].id < installer_vimenter[1].id,
        "Mason setup callback must have a lower autocmd id than mti_start (deletion depends on it)"
    )
end

-- 2. First genuine use initializes exactly once through the scheduled
--    VimEnter continuation; repeated events/direct calls do not double-run.
if type(mason_mod) == "table" and type(mason_mod.ensure_setup) == "function" then
    vim.api.nvim_exec_autocmds("VimEnter", {})
    local done = vim.wait(10000, function() return mason_mod.state.status == "done" end)
    check(done, "scheduled continuation must complete setup after VimEnter")

    check(package.loaded["mason"] ~= nil, "scheduled setup must load mason")
    check(mason_mod.state.status == "done", "setup must be marked done after the continuation")
    check(mason_mod.state.setup_runs == 1, "setup must run exactly once, got " .. tostring(mason_mod.state.setup_runs))
    check(
        mason_mod.state.continuation_runs == 1,
        "continuation must run exactly once, got " .. tostring(mason_mod.state.continuation_runs)
    )
    check(
        mason_mod.state.auto_check_scheduled,
        "configured mason-tool-installer run_on_start() must have been invoked once by the continuation"
    )
    check(
        #vim.api.nvim_get_autocmds({ group = "mti_start" }) == 0,
        "mti_start autocmds must have been deleted by the VimEnter callback"
    )
    check(
        path_count_bin(mason_bin) == 1,
        "PATH must contain exactly one mason bin entry after setup (mason manages its own)"
    )
    check(vim.fn.exists(":Mason") == 2, ":Mason must be defined after setup")
    check(vim.fn.exists(":MasonInstall") == 2, ":MasonInstall must be defined after setup")
    check(vim.fn.exists(":MasonToolsInstallSync") == 2, "MasonTools commands must remain usable")

    -- Repeated trigger paths are no-ops: VimEnter (once consumed), direct
    -- calls, CmdUndefined for an arbitrary Mason* name.
    vim.api.nvim_exec_autocmds("VimEnter", {})
    vim.api.nvim_exec_autocmds("CmdUndefined", { pattern = "MasonFoo" })
    mason_mod.ensure_setup()
    mason_mod.ensure_setup()
    check(
        mason_mod.state.setup_runs == 1 and mason_mod.state.continuation_runs == 1,
        "repeated triggers must not re-run setup or the continuation"
    )
else
    table.insert(failures, "cannot exercise scheduled path: plugins.mason has no ensure_setup")
end

-- 3. Tokyo Night startup-critical behavior preserved (state, not source).
--    The ColorSchemePre hook is `once = true`: it fires during startup when
--    the colorscheme is applied, so a healthy startup has already consumed it
--    (group is empty). If it were still registered, setup had not been
--    triggered at startup — a regression.
check(vim.g.colors_name == "tokyonight-moon", "the configured theme must still be applied at startup")
local tokyonight = vim.api.nvim_get_autocmds({ group = "tokyonight_lazy_setup" })
check(#tokyonight == 0, "tokyonight ColorSchemePre hook must have fired once during startup")

-- 4. todo-comments first-buffer behavior preserved.
local todo_group = vim.api.nvim_get_autocmds({ group = "todo_comments_lazy" })
check(#todo_group > 0, "todo-comments lazy autocmd is missing")

-- Fresh-subprocess probes. Each copies the parent environment (including the
-- disposable XDG roots from scripts/test-config.sh) plus explicit overrides.
local function run_probe(source, env_overrides)
    local nvim_bin = vim.fn.exepath("nvim")
    local probe_file = vim.fn.tempname() .. ".lua"
    vim.fn.writefile(vim.split(source, "\n", { plain = true }), probe_file)
    local env = {}
    for k, v in pairs(vim.fn.environ()) do
        env[k] = v
    end
    for k, v in pairs(env_overrides or {}) do
        if v == nil then
            env[k] = nil
        else
            env[k] = v
        end
    end
    local probe = vim.system({ nvim_bin, "--headless", "-n", "+luafile " .. probe_file }, { env = env, text = true })
    local result = probe:wait(60000)
    if result == nil then
        probe:kill()
        os.remove(probe_file)
        return { code = -1, stdout = "", stderr = "probe timed out" }
    end
    os.remove(probe_file)
    return result
end

-- 5. Bootstrap mode requires synchronous Mason setup: a fresh headless nvim
--    with NVIM_BOOTSTRAP=1 must have mason loaded and commands defined at
--    +luafile time (before VimEnter), with exactly one setup run.
local bootstrap_probe = table.concat({
    "local ok, err = pcall(function()",
    "local m = require('plugins.mason')",
    "assert(package.loaded['mason'] ~= nil, 'mason not loaded synchronously')",
    "assert(vim.fn.exists(':Mason') == 2, ':Mason missing')",
    "assert(vim.fn.exists(':MasonToolsInstallSync') == 2, ':MasonToolsInstallSync missing')",
    "assert(type(m) == 'table', 'plugins.mason must expose state, got ' .. type(m))",
    "assert(m.state.status == 'done', 'setup must be done, got ' .. tostring(m.state.status))",
    "assert(m.state.setup_runs == 1, 'setup must run exactly once, got ' .. tostring(m.state.setup_runs))",
    "assert(m.state.setup_attempts == 1, 'setup must attempt exactly once, got ' .. tostring(m.state.setup_attempts))",
    "end)",
    "if not ok then",
    "io.stderr:write('BOOTSTRAP_PROBE_FAILED: ' .. tostring(err) .. '\\\\n')",
    "vim.cmd('cquit 1')",
    "end",
    "vim.cmd('qa!')",
}, "\n")
local bootstrap_result = run_probe(bootstrap_probe, { NVIM_BOOTSTRAP = "1", NVIM_CONFIG_TEST = "1" })
check(
    bootstrap_result.code == 0,
    "bootstrap synchronous-setup probe failed (code "
        .. tostring(bootstrap_result.code)
        .. "): "
        .. tostring(bootstrap_result.stderr)
        .. " | stdout: "
        .. tostring(bootstrap_result.stdout)
)

-- 6. CmdUndefined real user command path: a fresh headless instance must stay
--    deferred (like any pre-VimEnter invocation), then invoking the genuinely
--    undefined noninteractive :MasonLog fires CmdUndefined("MasonLog"), runs
--    ensure_setup() exactly once, defines the :Mason* command set, and Neovim
--    retries the command so its handler actually executes (observable via the
--    `tabnew` side effect). Re-invoking the now-defined command must not
--    re-run setup. This process quits before VimEnter, so the auto-check must
--    NOT have been arranged — that is the VimEnter continuation's job.
local cmd_probe = table.concat({
    "local fired = nil",
    "vim.api.nvim_create_autocmd('CmdUndefined', { pattern = 'MasonLog', callback = function(a) fired = a.match end })",
    "local ok, err = pcall(function()",
    "    local m = require('plugins.mason')",
    "    assert(package.loaded['mason'] == nil, 'mason must stay deferred before a :Mason* command')",
    "    assert(m.state.status == 'not_started', 'setup must not run before a :Mason* command')",
    "    assert(vim.fn.exists(':MasonLog') ~= 2, ':MasonLog must be undefined before the trigger')",
    "    assert(fired == nil, 'CmdUndefined must not have fired yet')",
    "    local tabs_before = #vim.api.nvim_list_tabpages()",
    "    assert(pcall(vim.cmd, 'MasonLog'), ':MasonLog must be retried and executed after CmdUndefined setup')",
    "    assert(fired == 'MasonLog', 'CmdUndefined must fire for the real command name, got ' .. tostring(fired))",
    "    assert(package.loaded['mason'] ~= nil, 'CmdUndefined must have loaded mason')",
    "    assert(m.state.status == 'done', 'setup must be marked done after the CmdUndefined trigger')",
    "    assert(m.state.setup_runs == 1, 'setup must run exactly once, got ' .. tostring(m.state.setup_runs))",
    "    assert(vim.fn.exists(':MasonLog') == 2, ':MasonLog must be defined after the CmdUndefined trigger')",
    "    assert(vim.fn.exists(':Mason') == 2, ':Mason must be defined after the CmdUndefined trigger')",
    "    assert(#vim.api.nvim_list_tabpages() == tabs_before + 1, ':MasonLog handler must have run (tabnew side effect)')",
    "    assert(pcall(vim.cmd, 'MasonLog'), 'repeated :MasonLog must still execute')",
    "    assert(m.state.setup_runs == 1, 'repeated command must not re-run setup (no recursion)')",
    "    assert(m.state.auto_check_scheduled == false, 'auto-check must not be arranged before VimEnter')",
    "end)",
    "if not ok then",
    "io.stderr:write('CMDUNDEFINED_PROBE_FAILED: ' .. tostring(err) .. '\\\\n')",
    "vim.cmd('cquit 1')",
    "end",
    "vim.cmd('qa!')",
}, "\n")
local cmd_result = run_probe(cmd_probe, { NVIM_CONFIG_TEST = "1", NVIM_BOOTSTRAP = nil })
check(
    cmd_result.code == 0,
    "CmdUndefined real-command probe failed (code "
        .. tostring(cmd_result.code)
        .. "): "
        .. tostring(cmd_result.stderr)
        .. " | stdout: "
        .. tostring(cmd_result.stdout)
)

-- 7. Pre-VimEnter MasonTools* path: commands registered by
-- mason-tool-installer must be replaced by guarded wrappers. A real
-- :MasonToolsClean invocation must run setup first, then call the action once.
local tools_probe = table.concat({
    "local mti = require('mason-tool-installer')",
    "local clean_calls, clean_status = 0, nil",
    "mti.clean = function()",
    "    clean_calls = clean_calls + 1",
    "    clean_status = require('plugins.mason').state.status",
    "end",
    "local m = require('plugins.mason')",
    "vim.schedule(function()",
    "    local ok, err = pcall(function()",
    "        assert(m.state.status == 'not_started', 'must be deferred before MasonToolsClean')",
    "        vim.cmd('MasonToolsClean')",
    "        assert(m.state.status == 'done', 'MasonToolsClean must initialize setup first')",
    "        assert(m.state.setup_runs == 1, 'setup must run once')",
    "        assert(clean_calls == 1, 'clean action must run once, got ' .. tostring(clean_calls))",
    "        assert(clean_status == 'done', 'clean action must run after setup, got ' .. tostring(clean_status))",
    "    end)",
    "    if not ok then",
    "        io.stderr:write('MASON_TOOLS_PROBE_FAILED: ' .. tostring(err) .. '\\\\n')",
    "        vim.cmd('cquit 1')",
    "    end",
    "    vim.cmd('qa!')",
    "end)",
}, "\n")
local tools_result = run_probe(tools_probe, { NVIM_CONFIG_TEST = "1", NVIM_BOOTSTRAP = nil })
check(
    tools_result.code == 0,
    "MasonTools guarded-command probe failed (code "
        .. tostring(tools_result.code)
        .. "): "
        .. tostring(tools_result.stderr)
        .. " | stdout: "
        .. tostring(tools_result.stdout)
)

-- 8. Injected setup failure: a fake mason module whose setup() errors. Setup
--    must attempt exactly once, the failure must be recorded, and every later
--    trigger (direct call, CmdUndefined, scheduled continuation) must rethrow
--    the SAME failure without rerunning or arranging the auto-check.
local failure_probe = table.concat({
    "package.loaded['mason'] = { setup = function() error('injected mason failure') end }",
    "local ok1, err1 = pcall(function()",
    "    local m = require('plugins.mason')",
    "    local sep = vim.loop.os_uname().sysname == 'Windows_NT' and ';' or ':'",
    "    local bin = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'bin')",
    "    local found = false",
    "    for part in (vim.env.PATH or ''):gmatch('[^' .. sep .. ']+') do",
    "        if part == bin then found = true end",
    "    end",
    "    assert(found, 'PATH must contain mason bin even with a broken mason module')",
    "    assert(m.state.status == 'not_started', 'must start deferred')",
    "    local ok, err = pcall(m.ensure_setup)",
    "    assert(not ok, 'setup must fail')",
    "    assert(tostring(err):find('injected mason failure', 1, true), 'failure must propagate, got: ' .. tostring(err))",
    "    assert(m.state.status == 'failed', 'state must be failed, got ' .. tostring(m.state.status))",
    "    assert(m.state.setup_attempts == 1, 'must attempt exactly once, got ' .. tostring(m.state.setup_attempts))",
    "    assert(m.state.setup_runs == 0, 'failed setup must not count as a run')",
    "    local ok2, err2 = pcall(m.ensure_setup)",
    "    assert(not ok2, 'later trigger must not silently succeed')",
    "    assert(tostring(err2) == tostring(err), 'later trigger must rethrow the same failure')",
    "    assert(m.state.setup_attempts == 1, 'later trigger must not re-run setup')",
    "    vim.api.nvim_exec_autocmds('CmdUndefined', { pattern = 'MasonLog' })",
    "    assert(m.state.setup_attempts == 1, 'CmdUndefined trigger must not re-run failed setup')",
    "    vim.api.nvim_exec_autocmds('VimEnter', {})",
    "    assert(#vim.api.nvim_get_autocmds({ group = 'mti_start' }) == 0, 'mti_start must be deleted even on failure')",
    "    vim.schedule(function()",
    "        local waited = vim.wait(5000, function() return m.state.continuation_runs == 1 end)",
    "        local ok3, err3 = pcall(function()",
    "            assert(waited, 'continuation must run')",
    "            assert(m.state.setup_attempts == 1, 'continuation must not re-run failed setup')",
    "            assert(m.state.setup_runs == 0, 'continuation must not count a run')",
    "            assert(m.state.status == 'failed', 'state must remain failed')",
    "            assert(m.state.auto_check_scheduled == false, 'auto-check must not be arranged after failure')",
    "        end)",
    "        if not ok3 then",
    "            io.stderr:write('FAILURE_PROBE_FAILED: ' .. tostring(err3) .. '\\\\n')",
    "            vim.cmd('cquit 1')",
    "        end",
    "        vim.cmd('qa!')",
    "    end)",
    "end)",
    "if not ok1 then",
    "io.stderr:write('FAILURE_PROBE_SETUP_FAILED: ' .. tostring(err1) .. '\\\\n')",
    "vim.cmd('cquit 1')",
    "end",
}, "\n")
local failure_result = run_probe(failure_probe, { NVIM_CONFIG_TEST = "1", NVIM_BOOTSTRAP = nil })
check(
    failure_result.code == 0,
    "injected-failure probe failed (code "
        .. tostring(failure_result.code)
        .. "): "
        .. tostring(failure_result.stderr)
        .. " | stdout: "
        .. tostring(failure_result.stdout)
)

-- 9. Natural empty startup: no file argument, no manual event dispatch. The
--    real VimEnter fires after the +luafile command returns; our callback
--    neutralizes mti_start and schedules the continuation, which sets up once
--    and invokes the configured mason-tool-installer run_on_start() exactly
--    once (observable via a patched counter).
local natural_probe = table.concat({
    "local calls = 0",
    "local mti = require('mason-tool-installer')",
    "local orig_run_on_start = mti.run_on_start",
    "mti.run_on_start = function()",
    "    calls = calls + 1",
    "    return orig_run_on_start()",
    "end",
    "local m = require('plugins.mason')",
    "local sep = vim.loop.os_uname().sysname == 'Windows_NT' and ';' or ':'",
    "local ci = sep == ';'",
    "local bin = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'bin')",
    "local function bin_count()",
    "    local n = 0",
    "    local target = ci and bin:lower() or bin",
    "    for part in (vim.env.PATH or ''):gmatch('[^' .. sep .. ']+') do",
    "        local p = ci and part:lower() or part",
    "        if p == target then n = n + 1 end",
    "    end",
    "    return n",
    "end",
    "local ok0, err0 = pcall(function()",
    "    assert(package.loaded['mason'] == nil, 'mason must not be loaded before VimEnter')",
    "    assert(m.state.status == 'not_started', 'must start deferred')",
    "    assert(bin_count() >= 1, 'PATH must contain mason bin before VimEnter')",
    "    assert(vim.fn.exists(':Mason') ~= 2, ':Mason must be undefined pre-setup')",
    "    local ours = vim.api.nvim_get_autocmds({ group = 'mason_deferred_setup', event = 'VimEnter' })",
    "    local theirs = vim.api.nvim_get_autocmds({ group = 'mti_start', event = 'VimEnter' })",
    "    assert(#theirs == 1, 'mti_start must exist pre-VimEnter')",
    "    assert(ours[1].id < theirs[1].id, 'our VimEnter id must precede mti_start (id ' .. ours[1].id .. ' vs ' .. theirs[1].id .. ')')",
    "end)",
    "if not ok0 then",
    "io.stderr:write('NATURAL_PROBE_PRE_FAILED: ' .. tostring(err0) .. '\\\\n')",
    "vim.cmd('cquit 1')",
    "end",
    "vim.schedule(function()",
    "    local waited = vim.wait(10000, function() return m.state.status == 'done' end)",
    "    local ok, err = pcall(function()",
    "        assert(waited, 'scheduled continuation must complete setup')",
    "        assert(m.state.status == 'done', 'setup must complete')",
    "        assert(m.state.setup_runs == 1, 'setup must run exactly once, got ' .. tostring(m.state.setup_runs))",
    "        assert(m.state.setup_attempts == 1, 'setup must attempt exactly once')",
    "        assert(m.state.continuation_runs == 1, 'continuation must run exactly once')",
    "        assert(calls == 1, 'configured run_on_start() must be invoked exactly once, got ' .. tostring(calls))",
    "        assert(m.state.auto_check_scheduled, 'auto-check must be marked scheduled')",
    "        assert(#vim.api.nvim_get_autocmds({ group = 'mti_start' }) == 0, 'mti_start must be deleted')",
    "        assert(vim.fn.exists(':Mason') == 2, ':Mason must be defined after setup')",
    "        assert(bin_count() == 1, 'PATH must contain exactly one mason bin entry after setup')",
    "    end)",
    "    if not ok then",
    "        io.stderr:write('NATURAL_PROBE_FAILED: ' .. tostring(err) .. '\\\\n')",
    "        vim.cmd('cquit 1')",
    "    end",
    "    io.stdout:write('NATURAL_PROBE_OK\\\\n')",
    "    vim.cmd('qa!')",
    "end)",
}, "\n")
local natural_result = run_probe(natural_probe, { NVIM_CONFIG_TEST = "1", NVIM_BOOTSTRAP = nil })
check(
    natural_result.code == 0,
    "natural empty-startup probe failed (code "
        .. tostring(natural_result.code)
        .. "): "
        .. tostring(natural_result.stderr)
        .. " | stdout: "
        .. tostring(natural_result.stdout)
)

if #failures > 0 then
    io.stderr:write("LIFECYCLE_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("LIFECYCLE_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
