-- 补全与片段（mini.snippets，经 vim.pack）
--
-- 原生 vim.lsp.completion（在 config/lsp.lua 中启用）提供 LSP 驱动的补全；
-- mini.snippets 从 snippets/ 目录的 JSON 片段文件提供片段展开。
--
-- 不需要第三方补全引擎（nvim-cmp、blink.cmp）。
-- Markdown 只排除 LSP 补全，片段展开仍然可用。

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.snippets" },
})

local mini_snippets = require("mini.snippets")
local gen_loader = mini_snippets.gen_loader

mini_snippets.setup({
    -- 从配置目录（runtimepath）解析 snippets/<filetype>.json
    snippets = {
        gen_loader.from_lang(),
    },
})
