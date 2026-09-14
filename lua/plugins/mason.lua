-- Mason: package manager, LSP-name bridge, and tool installer.
--
-- Setup only registers commands / UI (no network work). mason-tool-installer's
-- background install check runs behind its own start_delay, so it never sits on
-- the startup critical path.

vim.pack.add({
    -- mason-org is the upstream home; the old williamboman/* URLs survive
    -- only via GitHub rename redirects, so don't depend on them.
    { src = "https://github.com/mason-org/mason.nvim" },
    -- Maps nvim-lspconfig server names (lua_ls, ts_ls, ...) to Mason
    -- package names for mason-tool-installer; activation of the servers
    -- themselves is handled by config/lsp.lua via vim.lsp.enable().
    { src = "https://github.com/mason-org/mason-lspconfig.nvim" },
    { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
})

require("mason").setup()
require("mason-lspconfig").setup({ automatic_enable = false })
require("mason-tool-installer").setup({
    ensure_installed = require("config.util").mason_packages,
    auto_update = false,
    run_on_start = true,
    start_delay = 1000,
    debounce_hours = 24,
})
