-- ~/.config/nvim/lua/config/lsp_completion.lua
-- Native LSP completion activation (testable unit).
--
-- Owns three behaviors, all exercised behaviorally by tests/check_completion.lua:
--   1. enable_for_client()  — the LspAttach callback: enables native completion
--      per attached client that supports textDocument/completion. Markdown is
--      intentionally excluded so prose buffers never pay for completion
--      requests or popups.
--   2. trigger()            — the <C-Space> handler: requests completion in
--      code buffers and stays inert in Markdown.
--   3. register()           — wires the LspAttach autocmd.

local M = {}

local function is_markdown(bufnr) return vim.bo[bufnr].filetype == "markdown" end

---Enable native LSP completion for one LspAttach event.
---@param args { buf: integer, data: { client_id: integer } }
---@return boolean true when completion was enabled
function M.enable_for_client(args)
    if is_markdown(args.buf) then return false end

    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/completion", args.buf) then
        vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
        return true
    end
    return false
end

---<C-Space> behavior: request completion outside Markdown.
---@return boolean true when a completion request was issued
function M.trigger()
    if vim.bo.filetype == "markdown" then return false end
    vim.lsp.completion.get()
    return true
end

---Register the LspAttach autocmd that activates completion per client.
function M.register()
    vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_completion", { clear = true }),
        callback = M.enable_for_client,
    })
end

return M
