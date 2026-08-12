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

local mini_snippets = require("mini.snippets")
local gen_loader = mini_snippets.gen_loader

mini_snippets.setup({
    -- Resolve snippets/<filetype>.json from the config directory on runtimepath.
    snippets = {
        gen_loader.from_lang(),
    },
})

-- Prose editing should stay completely unaffected by snippet matching.
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("disable_markdown_snippets", { clear = true }),
    pattern = "markdown",
    callback = function(args) vim.b[args.buf].minisnippets_disable = true end,
})
