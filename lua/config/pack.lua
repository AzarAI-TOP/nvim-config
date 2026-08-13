-- vim.pack-based plugin update / list commands (no third-party plugin manager).
-- :PackUpdate updates all managed plugins; :PackList lists plugins in fzf-lua.

local M = {}

---Pure row builder for :PackList (testable; vim.pack.get() can be injected at call time).
---@return string[] rows sorted by plugin name: "name  source  rev"
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
        vim.notify("fzf-lua unavailable", vim.log.levels.ERROR)
        return
    end
    fzf.fzf_exec(M.entries(), { prompt = "plugins> " })
end

-- Follows the official vim.pack update flow (:help pack-update):
-- downloads updates and opens a confirmation buffer in a separate tabpage —
-- :write applies the changes, :quit discards them, optionally :restart loads
-- the updated plugin code.
vim.api.nvim_create_user_command("PackUpdate", function()
    local ok, err = pcall(vim.pack.update)
    if not ok then
        vim.notify("Plugin update failed: " .. tostring(err), vim.log.levels.ERROR, { title = "PackUpdate" })
    end
end, { desc = "Update vim.pack plugins (opens review buffer)", nargs = 0 })

vim.api.nvim_create_user_command("PackList", list_plugins, { desc = "List vim.pack plugins", nargs = 0 })

return M
