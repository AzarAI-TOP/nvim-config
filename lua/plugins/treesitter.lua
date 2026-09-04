-- Tree-sitter: parsers, highlighting, and textobject queries (via vim.pack)
--
-- Neovim's built-in 7 parsers don't cover languages like JavaScript;
-- missing parsers fall back to basic regex highlighting.

-- nvim-treesitter's new API lives on the main branch (Neovim 0.11+)
vim.pack.add({
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
    -- Textobject capture queries (@function.outer / @function.inner, ...).
    -- Data-only: nothing is loaded or set up — mini.ai's treesitter F target
    -- (plugins/mini.lua) reads queries/<lang>/textobjects.scm straight from
    -- the runtimepath. Upstream was archived 2026-04 and reopened 2026-07;
    -- query updates track parser changes (see README Future Considerations).
    { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" },
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
    "graphql",
    "vue",
    "svelte",
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

-- Enable Tree-sitter highlighting per filetype.
-- Neovim 0.12 does NOT auto-enable highlighting when a parser exists (only
-- ftplugin/lua.lua calls vim.treesitter.start() itself) — this FileType
-- autocmd is the enabling mechanism for every other filetype. The
-- pcall(language.add) guard is mandatory: vim.treesitter.start() asserts on
-- a missing parser instead of degrading to regex highlighting.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("treesitter_highlight", { clear = true }),
    callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then return end
        local ok, loaded = pcall(vim.treesitter.language.add, lang)
        if ok and loaded then vim.treesitter.start(args.buf, lang) end
    end,
})
