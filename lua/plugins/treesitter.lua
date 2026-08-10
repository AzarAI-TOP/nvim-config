-- ~/.config/nvim/lua/plugins/treesitter.lua
-- Tree-sitter syntax highlighting (via vim.pack)
--
-- Neovim's 7 built-in parsers don't cover JavaScript, etc.
-- Missing parsers fall back to basic regex highlighting.

-- nvim-treesitter's new API lives on main (Neovim 0.11+)
vim.pack.add({
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
})

-- Parsers to install (language names, not filetypes).
-- Requires a C compiler (cc/gcc) on PATH.
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
    -- "jsonc", not supported
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

-- Async install/update parsers (already-installed ones are skipped)
if vim.env.NVIM_CONFIG_TEST ~= "1" then require("nvim-treesitter").install(parsers) end

-- Filetype -> parser mapping (when names differ)
vim.treesitter.language.register("javascript", { "javascriptreact" })
vim.treesitter.language.register("tsx", { "typescriptreact" })
vim.treesitter.language.register("bash", { "sh" })

-- Auto-enable Tree-sitter highlighting per filetype.
-- Only activates when a parser is installed; silently falls back
-- to regex highlighting otherwise.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
    callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then return end
        local ok, loaded = pcall(vim.treesitter.language.add, lang)
        if ok and loaded then vim.treesitter.start(args.buf, lang) end
    end,
})
