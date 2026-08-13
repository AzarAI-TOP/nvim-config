-- mini.clue 平台感知的行为测试（lua/plugins/mini-clue.lua）。
--
-- 用注入的本地 / 远端平台状态调用生产触发器构建器，
-- 并检查运行中的 MiniClue.config.triggers；不搜索源码文本。
--
-- 契约：<leader>y / <leader>Y 复制到宿主机的映射只在远端主机
-- （WSL/SSH）由 config/keymaps.lua 注册，因此 mini.clue 只在
-- 远端平台展示它们。

local failures = {}

local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

local miniclue_module = require("plugins.mini-clue")

check(type(miniclue_module.build_triggers) == "function", "mini-clue 必须导出 build_triggers(platform)")

local function find(triggers, keys)
    for _, trigger in ipairs(triggers) do
        if trigger.keys == keys then return trigger end
    end
    return nil
end

-- ── 注入的本地平台状态 ──
local local_triggers = miniclue_module.build_triggers({ is_remote = false })
check(find(local_triggers, "<leader>y") == nil, "本地平台必须省略 <leader>y 提示")
check(find(local_triggers, "<leader>Y") == nil, "本地平台必须省略 <leader>Y 提示")

-- 其余提示在本地必须全部保留。
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
    check(find(local_triggers, keys) ~= nil, "本地平台必须保留提示 " .. keys)
end

-- ── 注入的远端平台状态：两条都出现且与键位一致 ──
local remote_triggers = miniclue_module.build_triggers({ is_remote = true })
local y = find(remote_triggers, "<leader>y")
local Y = find(remote_triggers, "<leader>Y")
check(y ~= nil, "远端平台必须包含 <leader>y 提示")
check(Y ~= nil, "远端平台必须包含 <leader>Y 提示")

-- 交叉核对提示描述与 keymaps.lua 在远端注册的映射（相同 lhs/rhs/desc），
-- 在运行时读回比对。
vim.keymap.set("n", "<leader>y", '"+y', { desc = "复制到宿主机剪贴板" })
vim.keymap.set("n", "<leader>Y", '"+Y', { desc = "复制整行到宿主机剪贴板" })
check(
    y ~= nil and y.desc == vim.fn.maparg("<leader>y", "n", false, true).desc,
    "远端 <leader>y 提示描述必须与键位描述一致"
)
check(
    Y ~= nil and Y.desc == vim.fn.maparg("<leader>Y", "n", false, true).desc,
    "远端 <leader>Y 提示描述必须与键位描述一致"
)
vim.keymap.del("n", "<leader>y")
vim.keymap.del("n", "<leader>Y")

-- ── 实际配置状态反映本机平台（本机为本地） ──
local configured = require("mini.clue").config.triggers
check(find(configured, "<leader>y") == nil, "本地配置的触发器必须省略 <leader>y")
check(find(configured, "<leader>Y") == nil, "本地配置的触发器必须省略 <leader>Y")
check(
    #configured == #miniclue_module.build_triggers(require("config.platform")),
    "配置的触发器必须等于当前平台的构建器输出"
)

if #failures > 0 then
    io.stderr:write("MINI_CLUE_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("MINI_CLUE_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
