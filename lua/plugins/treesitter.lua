-- Tree-sitter syntax highlighting (via vim.pack)
--
-- Neovim's built-in 7 parsers don't cover languages like JavaScript;
-- missing parsers fall back to basic regex highlighting.

-- nvim-treesitter's new API lives on the main branch (Neovim 0.11+)
vim.pack.add({
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

-- Parsers to install (language names, not filetype names). Requires a C
-- compiler (cc/gcc) on PATH.
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
    -- "jsonc" is unsupported
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
    "kotlin",
}

-- Install / update parsers asynchronously (already installed ones are skipped);
-- bootstrap mode skips this
if vim.env.NVIM_BOOTSTRAP ~= "1" then require("nvim-treesitter").install(parsers) end

-- Filetype → parser mapping (when names differ)
vim.treesitter.language.register("javascript", { "javascriptreact" })
vim.treesitter.language.register("tsx", { "typescriptreact" })
vim.treesitter.language.register("bash", { "sh" })

-- Enable Tree-sitter highlighting per filetype:
-- only activates when the parser is installed, otherwise silently falls back
-- to regex highlighting.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
    callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then return end
        local ok, loaded = pcall(vim.treesitter.language.add, lang)
        if ok and loaded then vim.treesitter.start(args.buf, lang) end
    end,
})
