-- ~/.config/nvim/lua/plugins/completion.lua
-- Completion and snippets (mini.snippets, via vim.pack)
--
-- Native vim.lsp.completion (enabled in config/lsp.lua) provides LSP-driven
-- completion via <C-x><C-n>. mini.snippets provides snippet expansion from
-- JSON snippet files in the snippets/ directory.
--
-- No third-party completion engine (nvim-cmp, blink.cmp) is needed.
-- Markdown is intentionally excluded from snippet/completion scope to
-- preserve typing speed in prose.

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.snippets" },
})

require("mini.snippets").setup({
    -- Read VS Code-style JSON snippets from the config snippets/ directory.
    snippets = {
        -- mini.snippets automatically discovers files on the runtimepath.
        -- The snippets/ directory is added to runtimepath via the config root.
    },
})
