-- ~/.config/nvim/lua/plugins/completion.lua
-- Completion and snippets (mini.snippets, via vim.pack)
--
-- Native vim.lsp.completion (enabled in config/lsp.lua) provides LSP-driven
-- completion via <C-x><C-n>. mini.snippets provides snippet expansion from
-- JSON snippet files in the snippets/ directory.
--
-- No third-party completion engine (nvim-cmp, blink.cmp) is needed.
-- Markdown is excluded only from LSP completion; snippets remain available.

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.snippets" },
})

local mini_snippets = require("mini.snippets")
local gen_loader = mini_snippets.gen_loader

mini_snippets.setup({
    -- Resolve snippets/<filetype>.json from the config directory on runtimepath.
    snippets = {
        gen_loader.from_lang(),
    },
})
