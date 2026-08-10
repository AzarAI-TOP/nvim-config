-- ~/.config/nvim/lua/plugins/mason.lua
-- Mason: package manager for LSP servers, DAP, linters, formatters
--
-- LSP configs are in lua/lsp/<server>.lua (loaded by config.lsp).
-- nvim-lspconfig supplies the default cmd/filetypes/root_dir definitions;
-- Neovim's native vim.lsp.config API loads and extends those definitions.

vim.pack.add({
    { src = "https://github.com/williamboman/mason.nvim" },
    { src = "https://github.com/williamboman/mason-lspconfig.nvim" },
    { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
})

require("mason").setup()

require("mason-tool-installer").setup({
    ensure_installed = require("config.tools").mason_packages,
    auto_update = false,
    -- Tests use disposable XDG directories and must not leave background
    -- downloads running after assertions finish.
    run_on_start = vim.env.NVIM_CONFIG_TEST ~= "1",
    start_delay = 1000,
    debounce_hours = 24,
})
