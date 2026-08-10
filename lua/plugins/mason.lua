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

local automated = vim.env.NVIM_CONFIG_TEST == "1" or vim.env.NVIM_BOOTSTRAP == "1"
local tool_installer_options = {
    ensure_installed = require("config.tools").mason_packages,
    auto_update = false,
    -- Tests use disposable XDG directories and must not leave background
    -- downloads running after assertions finish.
    run_on_start = not automated,
    start_delay = 1000,
}
if not automated then tool_installer_options.debounce_hours = 24 end
require("mason-tool-installer").setup(tool_installer_options)
