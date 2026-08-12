-- Shared tool inventory for LSP setup, Mason, health checks, and tests.

local M = {}

-- Names use nvim-lspconfig / mason-lspconfig identifiers. Versions are pinned
-- through mason-tool-installer's `version` field for reproducible first boots.
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

M.mason_versions = {
    bashls = "5.6.0",
    black = "26.5.1",
    ["clang-format"] = "22.1.8",
    clangd = "22.1.6",
    cssls = "4.10.0",
    goimports = "v0.48.0",
    ["google-java-format"] = "v1.36.1",
    gopls = "v0.23.0",
    html = "4.10.0",
    isort = "8.0.1",
    jsonls = "4.10.0",
    kotlin_lsp = "kotlin-lsp/v262.9593.0",
    ktlint = "1.8.0",
    lua_ls = "3.19.0",
    prettierd = "0.29.0",
    pyright = "1.1.411",
    rust_analyzer = "2026-08-10.1",
    shfmt = "v3.13.1",
    stylua = "v2.5.2",
    taplo = "0.10.0",
    ts_ls = "5.3.0",
    yamlls = "1.24.0",
}

-- mason-tool-installer accepts a table entry with a version field. Keeping the
-- lspconfig aliases here preserves its integration while making versions clear.
M.mason_packages = {}
for _, name in ipairs(vim.list_extend(vim.deepcopy(M.lsp_servers), vim.deepcopy(M.mason_formatters))) do
    table.insert(
        M.mason_packages,
        { name, version = assert(M.mason_versions[name], "missing Mason version for " .. name) }
    )
end

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
