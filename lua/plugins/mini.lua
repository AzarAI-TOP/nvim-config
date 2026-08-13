-- mini.nvim 生态插件（经 vim.pack），全部集中在这一个文件。
-- 除注明外均使用默认配置。

-- ── 核心 mini.* 插件 ──
local core_plugins = {
    -- 文本对象 — 扩展内置文本对象 (i) (a)
    "ai",
    -- 注释切换 — gc（切换）、gcc（当前行）
    "comment",
    -- 图标提供者 — 供 mini.files 等使用的文件 / 目录 / LSP 图标
    "icons",
    -- 缩进范围可视化
    "indentscope",
    -- 移动行 / 选区 — Alt+↑/↓
    "move",
    -- 尾随空白高亮与清理
    "trailspace",
}

for _, name in ipairs(core_plugins) do
    vim.pack.add({
        { src = "https://github.com/nvim-mini/mini." .. name },
    })
    require("mini." .. name).setup()
end

-- ── 括号导航 ──
-- treesitter 目标禁用：与 todo-comments 的 ]t/[t 冲突
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.bracketed" },
})

require("mini.bracketed").setup({
    treesitter = { suffix = "" },
})

-- ── 键位发现 ──
-- 按下前缀键时在浮动窗口显示可用键位，覆盖本配置的全部 <leader> 分组。
-- 复制到宿主机的 <leader>y / <leader>Y 只在远端（WSL/SSH）注册，
-- 因此只在远端平台作为提示展示。
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.clue" },
})

local miniclue = require("mini.clue")

local clue_triggers = {
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
if require("config.platform").is_remote then
    table.insert(clue_triggers, { mode = "n", keys = "<leader>y", desc = "复制到宿主机剪贴板" })
    table.insert(clue_triggers, { mode = "n", keys = "<leader>Y", desc = "复制整行到宿主机剪贴板" })
end

miniclue.setup({
    triggers = clue_triggers,

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

-- ── 文件浏览器 ──
-- Miller 列式导航；替代 netrw 成为默认文件浏览器；
-- 可用时自动使用 mini.icons 提供文件图标。
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.files" },
})

require("mini.files").setup({
    options = {
        -- 替代 `:e <目录>` 等场景中的 netrw
        use_as_default_explorer = true,
    },
    windows = {
        preview = true, -- 显示光标下文件的预览
    },
})

-- ── 通知系统 ──
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.notify" },
})

require("mini.notify").setup({
    window = {
        config = {
            focusable = true,
        },
    },
})

-- ── 补全与片段（mini.snippets） ──
-- 原生 vim.lsp.completion（在 config/lsp.lua 中启用）提供 LSP 驱动的补全；
-- mini.snippets 从 snippets/ 目录的 JSON 片段文件提供片段展开。
-- 不需要第三方补全引擎（nvim-cmp、blink.cmp）。
-- Markdown 只排除 LSP 补全，片段展开仍然可用。
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.snippets" },
})

local mini_snippets = require("mini.snippets")
mini_snippets.setup({
    -- 从配置目录（runtimepath）解析 snippets/<filetype>.json
    snippets = {
        mini_snippets.gen_loader.from_lang(),
    },
})

-- ── 命令 ──

-- :TrimTrailSpace — 删除尾随空白与尾随空行
-- force=true：config.reload 重跑本文件时可覆盖重建，不会报"命令已存在"。
vim.api.nvim_create_user_command("TrimTrailSpace", function()
    local view = vim.fn.winsaveview()
    require("mini.trailspace").trim()
    require("mini.trailspace").trim_last_lines()
    vim.fn.winrestview(view)
end, { desc = "删除当前缓冲区的尾随空白和尾随空行", force = true })
