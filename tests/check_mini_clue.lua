-- Behavioral tests for mini.clue platform awareness (lua/plugins/mini-clue.lua).
--
-- The production trigger builder is invoked with injected local/remote platform
-- states and the actual runtime MiniClue.config.triggers are inspected; no
-- source text is searched.
--
-- Contract: <leader>y / <leader>Y copy-to-host mappings are registered by
-- config/keymaps.lua only on remote hosts, so mini.clue must advertise them
-- only for remote platforms.

local failures = {}

local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

local miniclue_module = require("plugins.mini-clue")

check(type(miniclue_module.build_triggers) == "function", "mini-clue must export build_triggers(platform)")

local function find(triggers, keys)
    for _, trigger in ipairs(triggers) do
        if trigger.keys == keys then return trigger end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Injected LOCAL platform state.
-- ---------------------------------------------------------------------------
local local_triggers = miniclue_module.build_triggers({ is_remote = false })
check(find(local_triggers, "<leader>y") == nil, "local platform must omit <leader>y clue")
check(find(local_triggers, "<leader>Y") == nil, "local platform must omit <leader>Y clue")

-- All other clues must be preserved on local.
local preserved = {
    "<leader>b",
    "<leader>c",
    "<leader>l",
    "<leader>f",
    "<leader>w",
    "<leader>t",
    "<leader>p",
    "<leader>s",
    "<leader>e",
    "<leader>nh",
    "<leader>q",
    "<leader>Q",
}
for _, keys in ipairs(preserved) do
    check(find(local_triggers, keys) ~= nil, "local platform must keep clue " .. keys)
end

-- ---------------------------------------------------------------------------
-- Injected REMOTE platform state: both entries present, matching keymaps.
-- ---------------------------------------------------------------------------
local remote_triggers = miniclue_module.build_triggers({ is_remote = true })
local y = find(remote_triggers, "<leader>y")
local Y = find(remote_triggers, "<leader>Y")
check(y ~= nil, "remote platform must include <leader>y clue")
check(Y ~= nil, "remote platform must include <leader>Y clue")

-- Cross-check the clue descriptions against the exact mappings keymaps.lua
-- registers on remote hosts (same lhs/rhs/desc), read back at runtime.
vim.keymap.set("n", "<leader>y", '"+y', { desc = "Copy to host clipboard" })
vim.keymap.set("n", "<leader>Y", '"+Y', { desc = "Copy line to host clipboard" })
check(
    y ~= nil and y.desc == vim.fn.maparg("<leader>y", "n", false, true).desc,
    "remote <leader>y clue desc must match the keymap desc"
)
check(
    Y ~= nil and Y.desc == vim.fn.maparg("<leader>Y", "n", false, true).desc,
    "remote <leader>Y clue desc must match the keymap desc"
)
vim.keymap.del("n", "<leader>y")
vim.keymap.del("n", "<leader>Y")

-- ---------------------------------------------------------------------------
-- Actual configured state reflects the live platform (this machine is local).
-- ---------------------------------------------------------------------------
local configured = require("mini.clue").config.triggers
check(find(configured, "<leader>y") == nil, "configured triggers must omit <leader>y on local")
check(find(configured, "<leader>Y") == nil, "configured triggers must omit <leader>Y on local")
check(
    #configured == #miniclue_module.build_triggers(require("config.platform")),
    "configured triggers must equal builder output for the live platform"
)

if #failures > 0 then
    io.stderr:write("MINI_CLUE_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("MINI_CLUE_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
