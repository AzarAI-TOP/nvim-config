-- 核心 mini.* 插件（经 vim.pack）
--
-- 由各自独立的小文件合并而来。除注明外均使用默认配置。

local mini_plugins = {
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

for _, name in ipairs(mini_plugins) do
    vim.pack.add({
        { src = "https://github.com/nvim-mini/mini." .. name },
    })
    require("mini." .. name).setup()
end

-- :TrimTrailSpace — 删除尾随空白与尾随空行
vim.api.nvim_create_user_command("TrimTrailSpace", function()
    local view = vim.fn.winsaveview()
    require("mini.trailspace").trim()
    require("mini.trailspace").trim_last_lines()
    vim.fn.winrestview(view)
end, { desc = "删除当前缓冲区的尾随空白和尾随空行" })
