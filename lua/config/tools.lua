-- Shared tool inventory for LSP setup, Mason, and health checks.

local M = {}

-- Names use nvim-lspconfig / mason-lspconfig identifiers.
M.lsp_servers = {
    "gopls",
    "clangd",
    "rust_analyzer",
    "ts_ls",
    "html",
    "cssls",
    "jsonls",
    "pyright",
    "lua_ls",
    "bashls",
    "yamlls",
    "kotlin_lsp",
}

-- Portable formatter packages available from the Mason registry.
-- gofmt and rustfmt intentionally come from the Go/Rust toolchains because
-- Mason does not publish standalone packages for them.
M.mason_formatters = {
    "black",
    "clang-format",
    "goimports",
    "isort",
    "prettierd",
    "shfmt",
    "stylua",
    "taplo",
    "google-java-format",
    "ktlint",
}

-- mason-tool-installer accepts plain package names.
M.mason_packages = vim.list_extend(vim.list_extend({}, M.lsp_servers), M.mason_formatters)

-- Required outside Mason. The Linux bootstrap script installs the generic
-- tools; language-specific formatters arrive with their native toolchains.
M.system_tools = {
    "git",
    "curl",
    "fzf",
    "rg",
    "node",
    "npm",
}

return M
