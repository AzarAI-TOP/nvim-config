-- Mason：包管理器、LSP 桥接与工具安装器。
-- 同步 setup：只注册命令 / 界面（不联网）；安装发生在启动之后，
-- 由 mason-tool-installer 配置的 run_on_start 触发。

vim.pack.add({
    { src = "https://github.com/williamboman/mason.nvim" },
    { src = "https://github.com/williamboman/mason-lspconfig.nvim" },
    { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
})

-- 测试 / 引导模式关闭自动安装检查，headless 运行绝不联网；
-- 引导流程仍通过 `+MasonToolsInstallSync` 立即安装（NVIM_BOOTSTRAP=1）。
local automated = vim.env.NVIM_CONFIG_TEST == "1" or vim.env.NVIM_BOOTSTRAP == "1"

local ok, err = pcall(function()
    require("mason").setup()
    -- 激活由 config/lsp.lua 通过 vim.lsp.enable() 负责。
    require("mason-lspconfig").setup({ automatic_enable = false })
    require("mason-tool-installer").setup({
        ensure_installed = require("config.util").mason_packages,
        auto_update = false,
        run_on_start = not automated,
        start_delay = 1000,
        debounce_hours = 24,
    })
end)
if not ok then vim.notify("Mason 初始化失败: " .. tostring(err), vim.log.levels.ERROR, { title = "mason" }) end
