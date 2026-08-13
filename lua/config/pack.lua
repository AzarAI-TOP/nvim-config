-- 基于 vim.pack 的插件更新 / 列表命令（无第三方插件管理器）。
-- :PackUpdate 更新全部受管插件；:PackList 在 fzf-lua 中列出插件。

local M = {}

---:PackList 的纯行构建器（可测试；vim.pack.get() 可在调用时注入）。
---@return string[] 按插件名排序的行："名称  来源  版本"
function M.entries()
    local rows = {}
    for _, plugin in ipairs(vim.pack.get()) do
        local spec = plugin.spec or {}
        table.insert(rows, string.format("%s  %s  %s", spec.name or "?", spec.src or "", plugin.rev or ""))
    end
    table.sort(rows)
    return rows
end

local function list_plugins()
    local ok, fzf = pcall(require, "fzf-lua")
    if not ok then
        vim.notify("fzf-lua 不可用", vim.log.levels.ERROR)
        return
    end
    fzf.fzf_exec(M.entries(), { prompt = "插件> " })
end

-- 遵循官方 vim.pack 更新流程（:help pack-update）：
-- 下载更新并在独立标签页打开确认缓冲——审查变更后 :write 应用、
-- :quit 丢弃，可选 :restart 加载更新后的插件代码。
vim.api.nvim_create_user_command("PackUpdate", function()
    local ok, err = pcall(vim.pack.update)
    if not ok then
        vim.notify("插件更新失败: " .. tostring(err), vim.log.levels.ERROR, { title = "PackUpdate" })
    end
end, { desc = "更新 vim.pack 插件（打开审查缓冲）", nargs = 0 })

vim.api.nvim_create_user_command("PackList", list_plugins, { desc = "列出 vim.pack 插件", nargs = 0 })

return M
