-- Thin wrapper around the runtime editorconfig module (Neovim 0.12 ships
-- require('editorconfig') with full property/glob support but no longer wires
-- it to buffer events itself). Project .editorconfig values take precedence
-- over the per-filetype indent defaults in config/autocmds.lua.

local M = {}

---True when the buffer's applied editorconfig props contain indent settings.
---@param bufnr integer
---@return boolean
function M.has_indent(bufnr)
    local applied = vim.b[bufnr].editorconfig
    if type(applied) ~= "table" then return false end
    return applied.indent_style ~= nil or applied.indent_size ~= nil or applied.tab_width ~= nil
end

---Re-apply the resolved .editorconfig values for a buffer (idempotent).
---Used when a late FileType event lets runtime ftplugin/indent files
---overwrite the project values.
---@param bufnr integer
function M.reapply(bufnr)
    local ok, editorconfig = pcall(require, "editorconfig")
    if not ok then return end
    pcall(editorconfig.config, bufnr)
end

---Apply .editorconfig properties on buffer read/create. The runtime module
---walks parent directories, honors root=true, and supports the full glob
---syntax; it stores the applied properties in b:editorconfig.
function M.setup()
    vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        group = vim.api.nvim_create_augroup("nvim_config_editorconfig", { clear = true }),
        callback = function(args)
            local ok, editorconfig = pcall(require, "editorconfig")
            if not ok then return end
            local ok2, err = pcall(editorconfig.config, args.buf)
            if not ok2 then
                vim.notify(
                    "editorconfig 应用失败: " .. tostring(err),
                    vim.log.levels.WARN,
                    { title = "editorconfig" }
                )
            end
        end,
    })
end

return M
