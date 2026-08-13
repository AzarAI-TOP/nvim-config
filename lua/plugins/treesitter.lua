-- Tree-sitter 语法高亮（经 vim.pack）
--
-- Neovim 内置的 7 个解析器不覆盖 JavaScript 等语言；
-- 缺失的解析器回退到基础正则高亮。

-- nvim-treesitter 的新 API 在 main 分支（Neovim 0.11+）
vim.pack.add({
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

-- 要安装的解析器（语言名，非文件类型名）。需要 PATH 上有 C 编译器（cc/gcc）。
local parsers = {
    "lua",
    "vim",
    "vimdoc",
    "query",
    "javascript",
    "typescript",
    "tsx",
    "html",
    "css",
    "scss",
    "json",
    -- "jsonc" 不受支持
    "yaml",
    "toml",
    "bash",
    "markdown",
    "markdown_inline",
    "python",
    "rust",
    "go",
    "c",
    "cpp",
    "java",
}

-- 异步安装 / 更新解析器（已安装的自动跳过）；引导模式跳过
if vim.env.NVIM_BOOTSTRAP ~= "1" then require("nvim-treesitter").install(parsers) end

-- 文件类型 → 解析器映射（名称不一致时）
vim.treesitter.language.register("javascript", { "javascriptreact" })
vim.treesitter.language.register("tsx", { "typescriptreact" })
vim.treesitter.language.register("bash", { "sh" })

-- 按文件类型自动启用 Tree-sitter 高亮：
-- 仅在解析器已安装时激活，否则静默回退到正则高亮。
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
    callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then return end
        local ok, loaded = pcall(vim.treesitter.language.add, lang)
        if ok and loaded then vim.treesitter.start(args.buf, lang) end
    end,
})
