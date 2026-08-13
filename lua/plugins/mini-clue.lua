-- 键位发现（mini.clue，经 vim.pack）
--
-- 按下前缀键时在浮动窗口显示可用的键位提示。
-- 覆盖本配置使用的全部 <leader> 前缀分组。
--
-- 复制到宿主机剪贴板的 <leader>y / <leader>Y 只在远端主机（WSL/SSH）
-- 由 config/keymaps.lua 注册，因此只在远端平台作为提示展示。
-- build_triggers(platform) 导出供测试注入本地 / 远端平台状态。

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.clue" },
})

local miniclue = require("mini.clue")

local M = {}

---为给定平台构建 mini.clue 的 triggers 数组。
---@param platform table 含 is_remote 布尔字段的平台表
---                       （见 config/platform.lua；测试注入桩）
---@return table mini.clue triggers 数组
function M.build_triggers(platform)
    local triggers = {
        -- <leader> 分组
        { mode = "n", keys = "<leader>b", desc = "+缓冲区" },
        { mode = "n", keys = "<leader>c", desc = "+配置" },
        { mode = "n", keys = "<leader>l", desc = "+语言" },
        { mode = "n", keys = "<leader>f", desc = "+查找" },
        { mode = "n", keys = "<leader>w", desc = "+窗口" },
        { mode = "n", keys = "<leader>t", desc = "+开关" },
        { mode = "n", keys = "<leader>p", desc = "+包管理" },
        { mode = "n", keys = "<leader>s", desc = "+分屏" },
        { mode = "n", keys = "<leader>e", desc = "文件浏览" },
        { mode = "n", keys = "<leader>nh", desc = "清除搜索高亮" },
        { mode = "n", keys = "<leader>q", desc = "退出" },
        { mode = "n", keys = "<leader>Q", desc = "全部退出" },
    }

    -- 与 config/keymaps.lua 的远端专属注册保持一致。
    if platform.is_remote then
        table.insert(triggers, { mode = "n", keys = "<leader>y", desc = "复制到宿主机剪贴板" })
        table.insert(triggers, { mode = "n", keys = "<leader>Y", desc = "复制整行到宿主机剪贴板" })
    end

    return triggers
end

miniclue.setup({
    triggers = M.build_triggers(require("config.platform")),

    clues = {
        miniclue.gen_clues.builtin_completion(),
    },

    window = {
        delay = 300,
        config = {
            border = "rounded",
        },
    },
})

return M
