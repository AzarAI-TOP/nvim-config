-- ~/.config/nvim/lua/config/lsp.lua
-- LSP configuration (pure Neovim 0.11+ native API)
--
-- Auto-loads per-server configs from lua/lsp/<server>.lua.
-- Mason handles installing LSP servers; mason-lspconfig provides
-- ensure_installed convenience.

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

-- Installation is centralized in mason-tool-installer so bootstrap scripts can
-- synchronously install LSP servers and formatters with one command. Explicit
-- vim.lsp.enable() below remains the only activation path.
require("mason-lspconfig").setup({
    automatic_enable = false,
})

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

-- Load each server's runtime definition and enable it.
for _, server in ipairs(servers) do
    vim.lsp.enable(server)
end
