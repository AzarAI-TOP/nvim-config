-- Registry of global keymaps owned by this config. Pure data module that is
-- intentionally NEVER cleared by config.reload: reload deletes every recorded
-- mapping first, then the keymap modules re-register (and re-record) them.

local M = { mappings = {} }

---Record a global keymap owned by this config.
---@param mode string|string[]
---@param lhs string
function M.register(mode, lhs)
    for _, m in ipairs(type(mode) == "table" and mode or { mode }) do
        table.insert(M.mappings, { mode = m, lhs = lhs })
    end
end

---Delete every recorded mapping (idempotent; mappings removed by hand or by
---plugins are skipped).
function M.delete_all()
    for _, m in ipairs(M.mappings) do
        pcall(vim.keymap.del, m.mode, m.lhs)
    end
    M.mappings = {}
end

return M
