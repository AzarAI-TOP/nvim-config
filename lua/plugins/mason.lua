-- Mason: package manager, LSP bridge, and tool installer.
-- Synchronous setup: only registers commands / UI (no network); installation
-- happens after startup, triggered by mason-tool-installer's run_on_start.

vim.pack.add({
    -- mason-org is the upstream home; the old williamboman/* URLs survive
    -- only via GitHub rename redirects, so don't depend on them.
    { src = "https://github.com/mason-org/mason.nvim" },
    { src = "https://github.com/mason-org/mason-lspconfig.nvim" },
    { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
})

-- Bootstrap mode disables the automatic install check: the installer only
-- registers commands and UI without touching the network; the bootstrap flow
-- completes installation right away via `+MasonToolsInstallSync` (NVIM_BOOTSTRAP=1).
local automated = vim.env.NVIM_BOOTSTRAP == "1"

local ok, err = pcall(function()
    require("mason").setup()
    -- Activation is handled by config/lsp.lua via vim.lsp.enable().
    require("mason-lspconfig").setup({ automatic_enable = false })
    require("mason-tool-installer").setup({
        ensure_installed = require("config.util").mason_packages,
        auto_update = false,
        run_on_start = not automated,
        start_delay = 1000,
        debounce_hours = 24,
    })
end)
if not ok then vim.notify("Mason init failed: " .. tostring(err), vim.log.levels.ERROR, { title = "mason" }) end
