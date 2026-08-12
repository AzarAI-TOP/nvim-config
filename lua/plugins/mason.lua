-- ~/.config/nvim/lua/plugins/mason.lua
-- Mason infrastructure: package manager, LSP bridge, and tool installer.
--
-- Phase one only adds these plugins to the runtime path. Registry-related
-- setup is deferred to the explicit User NvimConfigInfrastructureReady event
-- emitted by plugins/init.lua after all infrastructure modules are registered.

vim.pack.add({
    { src = "https://github.com/williamboman/mason.nvim" },
    { src = "https://github.com/williamboman/mason-lspconfig.nvim" },
    { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
})

vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("mason_deferred_setup", { clear = true }),
    pattern = "NvimConfigInfrastructureReady",
    once = true,
    callback = function()
        require("mason").setup()

        -- Native vim.lsp.enable() in config/lsp.lua is the sole activation owner.
        require("mason-lspconfig").setup({ automatic_enable = false })

        local automated = vim.env.NVIM_CONFIG_TEST == "1" or vim.env.NVIM_BOOTSTRAP == "1"
        local options = {
            ensure_installed = require("config.tools").mason_packages,
            auto_update = false,
            run_on_start = not automated,
            start_delay = 1000,
        }
        if not automated then options.debounce_hours = 24 end
        require("mason-tool-installer").setup(options)
    end,
})
