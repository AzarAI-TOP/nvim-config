-- Shared tool inventory for LSP setup, Mason, health checks, and tests.

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
}

-- mason-tool-installer understands both mason-lspconfig server names and
-- Mason package names. One inventory lets bootstrap scripts install the full
-- development environment synchronously.
M.mason_packages = vim.list_extend(vim.deepcopy(M.lsp_servers), vim.deepcopy(M.mason_formatters))

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
