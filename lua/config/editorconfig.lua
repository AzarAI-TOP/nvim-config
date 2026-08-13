-- Helpers around the runtime editorconfig integration. Neovim 0.12 wires
-- require('editorconfig') itself via plugin/editorconfig.lua (BufNewFile /
-- BufRead / BufFilePost, enabled by default), so this module deliberately
-- does NOT register its own application autocmd — that would double-apply
-- and re-register BufWritePre autocmds for trim_trailing_whitespace /
-- insert_final_newline on every event.

local M = {}

---True when the buffer's applied editorconfig props contain indent settings.
---@param bufnr integer
---@return boolean
function M.has_indent(bufnr)
    local applied = vim.b[bufnr].editorconfig
    if type(applied) ~= "table" then return false end
    return applied.indent_style ~= nil or applied.indent_size ~= nil or applied.tab_width ~= nil
end

---Re-assert the applied indent options after a late FileType event lets
---runtime ftplugin/indent handlers overwrite them. Mirrors the official
---property functions but writes buffer options only — it intentionally does
---NOT re-run editorconfig.config(), which would re-register write-autocmds.
---@param bufnr integer
function M.reapply_indent(bufnr)
    local applied = vim.b[bufnr].editorconfig
    if type(applied) ~= "table" then return end
    if applied.indent_style ~= nil then
        vim.bo[bufnr].expandtab = applied.indent_style == "space"
        if applied.indent_style == "tab" and applied.indent_size == nil then
            vim.bo[bufnr].shiftwidth = 0
            vim.bo[bufnr].softtabstop = 0
        end
    end
    if applied.indent_size ~= nil then
        if applied.indent_size == "tab" then
            vim.bo[bufnr].shiftwidth = 0
            vim.bo[bufnr].softtabstop = 0
        else
            local n = tonumber(applied.indent_size)
            vim.bo[bufnr].shiftwidth = n
            vim.bo[bufnr].softtabstop = -1
            if applied.tab_width == nil then vim.bo[bufnr].tabstop = n end
        end
    end
    if applied.tab_width ~= nil then vim.bo[bufnr].tabstop = tonumber(applied.tab_width) end
end

return M
