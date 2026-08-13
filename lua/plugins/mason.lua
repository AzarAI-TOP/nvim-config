-- Mason: package manager, LSP bridge, and tool installer.
-- Synchronous setup: registers commands/UI only (no network); installs happen
-- after startup via mason-tool-installer's configured run_on_start.

vim.pack.add({
    { src = "https://github.com/williamboman/mason.nvim" },
    { src = "https://github.com/williamboman/mason-lspconfig.nvim" },
    { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
})

-- Test/bootstrap modes disable the automatic install check so headless runs
-- never hit the network; bootstrap still installs eagerly via
-- `+MasonToolsInstallSync` (NVIM_BOOTSTRAP=1, used by scripts/).
local automated = vim.env.NVIM_CONFIG_TEST == "1" or vim.env.NVIM_BOOTSTRAP == "1"

local ok, err = pcall(function()
    require("mason").setup()
    -- config/lsp.lua owns activation via vim.lsp.enable().
    require("mason-lspconfig").setup({ automatic_enable = false })
    require("mason-tool-installer").setup({
        ensure_installed = require("config.tools").mason_packages,
        auto_update = false,
        run_on_start = not automated,
        start_delay = 1000,
        debounce_hours = 24,
    })
end)
if not ok then vim.notify("Mason setup failed: " .. tostring(err), vim.log.levels.ERROR, { title = "mason" }) end
