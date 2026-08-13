-- Tokyo Night 主题，事件范围的 setup。
--
-- vim.pack 使配色加载器在第一阶段可用；插件的 Lua setup 只在请求
-- Tokyo Night 配色时执行；随后启动流程正常请求配置的主题。
-- ColorScheme（加载之后）不能作为加载触发器，否则会形成循环依赖。

vim.pack.add({
    { src = "https://github.com/folke/tokyonight.nvim" },
})

vim.api.nvim_create_autocmd("ColorSchemePre", {
    group = vim.api.nvim_create_augroup("tokyonight_lazy_setup", { clear = true }),
    pattern = "tokyonight*",
    once = true,
    callback = function() require("tokyonight").setup({ style = "moon" }) end,
})

vim.cmd.colorscheme("tokyonight-moon")
