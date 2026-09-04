-- nvim-lspconfig: server base configs for the native vim.lsp API.
--
-- Eager on purpose: vim.lsp.config resolves lsp/<name>.lua from the
-- runtimepath on demand (first filetype attach), so the repo must be on the
-- runtimepath from startup — the 12 servers in config/lsp.lua depend on it.
-- Lives in its own file (not mason.lua) because its only consumer is the LSP
-- layer; Mason owns installation, not configuration.

vim.pack.add({
    { src = "https://github.com/neovim/nvim-lspconfig" },
})
