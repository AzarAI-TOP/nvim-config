-- ~/.config/nvim/lua/plugins/mason.lua
-- Mason infrastructure: package manager, LSP bridge, and tool installer.
--
-- Lifecycle (ordering guarantee only — no startup-performance claim):
--
--   * Module load (phase one, during init) — cheap PATH prepend only:
--     stdpath("data")/mason/bin is added to PATH so native LSP servers and
--     formatters resolve before any file attach. No mason module is required
--     for this step.
--   * The registry-heavy `require("mason").setup()` chain is NOT run during
--     module loading or during startup events. It runs exactly once, after
--     the interactive startup boundary:
--       - VimEnter — our callback is registered during init, before plugin
--         files load, so it has a lower autocmd id and runs first. It deletes
--         mason-tool-installer's built-in `mti_start` autocmd (which would
--         otherwise call run_on_start() with DEFAULT settings and refresh the
--         registry before our options are applied), then schedules an
--         idempotent continuation via vim.schedule(). The continuation runs
--         after every VimEnter callback has returned: it performs setup once
--         and then invokes mason-tool-installer's configured run_on_start()
--         exactly once (it defers check_install by start_delay internally).
--       - CmdUndefined("Mason*") — a :Mason* command invoked before that
--         (e.g. headless `-c` usage): setup runs immediately and
--         synchronously so Neovim can retry the now-defined command. The
--         later scheduled continuation no-ops setup and still arranges the
--         configured auto-check once.
--   * Bootstrap mode (NVIM_BOOTSTRAP=1) sets up synchronously at module load
--     so `+MasonToolsInstallSync` and first-boot CI observe eager,
--     deterministic behavior. Test mode (NVIM_CONFIG_TEST=1) stays deferred
--     like normal startup and disables the tool-installer auto-check
--     (run_on_start=false) so the suite can verify the deferred state and
--     trigger paths without network.
--
-- State machine: not_started -> running -> done | failed. A failure is
-- recorded and rethrown by every later trigger; setup is never silently
-- retried or double-run by subsequent events.

vim.pack.add({
    { src = "https://github.com/williamboman/mason.nvim" },
    { src = "https://github.com/williamboman/mason-lspconfig.nvim" },
    { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
})

-- Observable lifecycle state (asserted by tests/check_plugin_lifecycle.lua).
local state = {
    status = "not_started", -- not_started | running | done | failed
    setup_runs = 0, -- successful completions only
    setup_attempts = 0, -- entries into setup from not_started
    continuation_runs = 0, -- scheduled post-VimEnter continuations executed
    auto_check_scheduled = false, -- configured run_on_start() invoked once
    failed_err = nil,
    error_notified = false,
}

local augroup = vim.api.nvim_create_augroup("mason_deferred_setup", { clear = true })

-- Group name owned by mason-tool-installer's plugin/ file (pinned 443f1ef).
local mti_group = "mti_start"

-- --- PATH helpers ----------------------------------------------------------
-- mason's own bin dir (matches mason-core InstallLocation:bin() with the
-- default install_root_dir). Cheap string work; no mason module is loaded.

local function path_sep() return vim.loop.os_uname().sysname == "Windows_NT" and ";" or ":" end

local function mason_bin_dir() return vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin") end

local function path_has_bin()
    local bin = mason_bin_dir()
    local ci = vim.loop.os_uname().sysname == "Windows_NT"
    local target = ci and bin:lower() or bin
    for entry in (vim.env.PATH or ""):gmatch("[^" .. path_sep() .. "]+") do
        local e = ci and entry:lower() or entry
        if e == target then return true end
    end
    return false
end

local function prepend_mason_bin()
    if path_has_bin() then return end
    vim.env.PATH = mason_bin_dir() .. path_sep() .. (vim.env.PATH or "")
end

-- After a successful setup, mason manages PATH itself (default "prepend");
-- drop one occurrence of our explicit entry so the environment is not
-- duplicated. Identical strings, so removing the first match is safe even
-- when the entry pre-existed or mason re-added it.
local function remove_mason_bin_entry()
    local bin = mason_bin_dir()
    local ci = vim.loop.os_uname().sysname == "Windows_NT"
    local target = ci and bin:lower() or bin
    local keep, removed = {}, false
    for entry in (vim.env.PATH or ""):gmatch("[^" .. path_sep() .. "]+") do
        local e = ci and entry:lower() or entry
        if not removed and e == target then
            removed = true
        else
            table.insert(keep, entry)
        end
    end
    if removed then vim.env.PATH = table.concat(keep, path_sep()) end
end

local ensure_setup

-- mason-tool-installer registers these commands from its plugin/ file. Replace
-- them with guarded wrappers after plugin sourcing: every manual action first
-- completes our configured setup, so pre-VimEnter `+MasonTools*` invocations
-- cannot run against default/empty settings.
local tool_actions = {
    MasonToolsUpdate = function(installer) return installer.check_install(true) end,
    MasonToolsUpdateSync = function(installer) return installer.check_install(true, true) end,
    MasonToolsInstall = function(installer) return installer.check_install(false) end,
    MasonToolsInstallSync = function(installer) return installer.check_install(false, true) end,
    MasonToolsClean = function(installer) return installer.clean() end,
}

local function register_tool_commands()
    for name, action in pairs(tool_actions) do
        vim.api.nvim_create_user_command(name, function()
            ensure_setup()
            return action(require("mason-tool-installer"))
        end, { force = true })
    end
end

-- --- Setup with a state machine --------------------------------------------

local function notify_error(err)
    if state.error_notified then return end
    state.error_notified = true
    vim.notify(tostring(err), vim.log.levels.ERROR, { title = "mason" })
end

ensure_setup = function()
    if state.status == "done" then return true end
    if state.status == "failed" then
        -- Re-throw the recorded failure; never retry, never double-run.
        notify_error(state.failed_err)
        error(state.failed_err, 0)
    end
    if state.status == "running" then error("mason setup is already in progress", 0) end

    state.status = "running"
    state.setup_attempts = state.setup_attempts + 1

    local ok, err = pcall(function()
        require("mason").setup()

        -- Native vim.lsp.enable() in config/lsp.lua is the sole activation owner.
        require("mason-lspconfig").setup({ automatic_enable = false })

        local automated = vim.env.NVIM_CONFIG_TEST == "1" or vim.env.NVIM_BOOTSTRAP == "1"
        local options = {
            ensure_installed = require("config.tools").mason_packages,
            auto_update = false,
            run_on_start = not automated,
            start_delay = 1000,
        }
        if not automated then options.debounce_hours = 24 end
        require("mason-tool-installer").setup(options)
    end)

    if not ok then
        state.status = "failed"
        state.failed_err = err
        notify_error(err)
        error(err, 0)
    end

    state.status = "done"
    state.setup_runs = state.setup_runs + 1
    remove_mason_bin_entry()
    register_tool_commands()
    return true
end

-- --- Post-VimEnter continuation ----------------------------------------------

-- Invoke mason-tool-installer's configured run_on_start() exactly once. With
-- run_on_start=true it defers check_install by start_delay; in test/bootstrap
-- mode the configured value is false and the call is a no-op.
local function arrange_auto_check()
    if state.auto_check_scheduled then return end
    local ok, err = pcall(function() require("mason-tool-installer").run_on_start() end)
    if ok then
        state.auto_check_scheduled = true
    else
        vim.notify(
            "mason-tool-installer auto-check failed: " .. tostring(err),
            vim.log.levels.ERROR,
            { title = "mason" }
        )
    end
end

local schedule_pending = false
local function schedule_continuation()
    if schedule_pending then return end
    schedule_pending = true
    vim.schedule(function()
        schedule_pending = false
        state.continuation_runs = state.continuation_runs + 1
        local ok = pcall(ensure_setup)
        if not ok then
            return -- ensure_setup already surfaced the failure via notify_error
        end
        arrange_auto_check()
    end)
end

local function delete_mti_start()
    local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = mti_group })
    if not ok then return end
    for _, autocmd in ipairs(autocmds) do
        vim.api.nvim_del_autocmd(autocmd.id)
    end
end

-- --- Trigger wiring -----------------------------------------------------------

local function on_vimenter()
    -- Runs before mti_start (lower autocmd id). Deleting those autocmds
    -- prevents their callbacks from executing during this dispatch, so the
    -- plugin's DEFAULT-settings run_on_start() (registry refresh) cannot run.
    delete_mti_start()
    schedule_continuation()
end

local function on_cmd_undefined()
    -- A :Mason* command was invoked before the scheduled continuation (e.g.
    -- headless `-c` usage). Setup must complete synchronously so Neovim can
    -- retry the now-defined command. Failures were already surfaced once by
    -- notify_error(); do not re-notify here.
    pcall(ensure_setup)
end

vim.api.nvim_create_autocmd("VimEnter", { group = augroup, once = true, callback = on_vimenter })
vim.api.nvim_create_autocmd("CmdUndefined", { group = augroup, pattern = "Mason*", callback = on_cmd_undefined })

prepend_mason_bin()

-- vim.pack may source plugin/ files after this module returns. Schedule the
-- force=true wrappers so they are installed after that sourcing but before
-- command-line `+MasonTools*` commands are processed.
vim.schedule(register_tool_commands)

-- Bootstrap mode keeps synchronous setup so `+MasonToolsInstallSync` works.
-- The test harness (NVIM_CONFIG_TEST=1) stays deferred like normal startup so
-- the suite can verify the deferred state and trigger paths.
if vim.env.NVIM_BOOTSTRAP == "1" then ensure_setup() end

return { ensure_setup = ensure_setup, state = state }
