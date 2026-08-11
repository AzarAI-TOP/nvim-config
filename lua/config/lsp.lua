-- ~/.config/nvim/lua/config/lsp.lua
-- LSP configuration (pure Neovim 0.11+ native API)
--
-- Auto-loads per-server configs from lua/lsp/<server>.lua.
-- Mason handles installing LSP servers; mason-lspconfig provides
-- ensure_installed convenience.
--
-- Mason is NOT loaded here during startup. It is lazily required only when
-- the mason-lspconfig mapping is needed (for verification/bootstrap). The
-- `require("mason-lspconfig").setup()` call is moved to plugins/mason.lua
-- to keep startup fast.

-- Diagnostic display configuration
vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
        border = "rounded",
        source = "if_many",
        header = "",
        prefix = "",
    },
})

-- LSP servers to install (names match mason-lspconfig registry).
local servers = require("config.tools").lsp_servers

-- Auto-load per-server configs from lua/lsp/<server>.lua
-- Each file must return a config table (or empty for defaults).
local lsp_dir = vim.fn.stdpath("config") .. "/lua/lsp"
local config_modules = {}
for name, ftype in vim.fs.dir(lsp_dir) do
    if ftype == "file" and name:match("%.lua$") then table.insert(config_modules, (name:gsub("%.lua$", ""))) end
end
table.sort(config_modules)

for _, server_name in ipairs(config_modules) do
    local ok, config = pcall(require, "lsp." .. server_name)
    if not ok then
        vim.notify("Failed to load LSP config for " .. server_name .. ": " .. tostring(config), vim.log.levels.ERROR)
    elseif type(config) ~= "table" then
        vim.notify("LSP config for " .. server_name .. " must return a table", vim.log.levels.ERROR)
    else
        vim.lsp.config(server_name, config)
    end
end

-- Enable native LSP completion (Neovim 0.12+).
-- This provides <C-x><C-n> style completion using LSP sources without
-- requiring a third-party completion plugin. Guarded with pcall because
-- the call fails when no LSP clients are attached yet (e.g. in tests).
pcall(vim.lsp.completion.enable, true)

-- Load each server's runtime definition and enable it.
for _, server in ipairs(servers) do
    vim.lsp.enable(server)
end

-- LSP keymaps are set per-buffer on LspAttach to avoid errors when
-- no LSP client is attached. See config/keymaps.lua for global mappings
-- and the LspAddgroup below for buffer-local ones.
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("lsp_attach_keymaps", { clear = true }),
    callback = function(args)
        local bufnr = args.buf
        local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc }) end

        map("n", "<leader>ld", vim.lsp.buf.definition, "Go to definition")
        map("n", "<leader>lh", function() vim.lsp.buf.hover({ border = "rounded" }) end, "Hover documentation")
        map("n", "<leader>lr", vim.lsp.buf.references, "Find references")
        map("n", "<leader>lR", vim.lsp.buf.rename, "Rename symbol")
        map("n", "<leader>la", vim.lsp.buf.code_action, "Code action")
        map("n", "<leader>li", vim.lsp.buf.implementation, "Go to implementation")
        map("n", "<leader>ls", function() vim.lsp.buf.signature_help({ border = "rounded" }) end, "Signature help")
    end,
})
