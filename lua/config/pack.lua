-- Plugin update/list commands on top of vim.pack (no plugin manager).
-- :PackUpdate updates every managed plugin; :PackList shows them in fzf-lua.

local M = {}

---Pure row builder for :PackList (testable; vim.pack.get() injectable).
---@return string[] rows sorted by plugin name: "name  src  rev"
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
    fzf.fzf_exec(M.entries(), { prompt = "Plugins> " })
end

-- Follows the official vim.pack update workflow (:help pack-update):
-- downloads updates and opens a confirmation buffer in a separate tabpage —
-- review the changes, :write to apply them, :quit to discard, optionally
-- :restart to load updated plugin code.
vim.api.nvim_create_user_command("PackUpdate", function()
    local ok, err = pcall(vim.pack.update)
    if not ok then
        vim.notify("插件更新失败: " .. tostring(err), vim.log.levels.ERROR, { title = "PackUpdate" })
    end
end, { desc = "Update vim.pack plugins (review buffer)", nargs = 0 })

vim.api.nvim_create_user_command("PackList", list_plugins, { desc = "List vim.pack plugins", nargs = 0 })

return M
