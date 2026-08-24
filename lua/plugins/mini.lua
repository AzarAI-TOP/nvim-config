-- mini.nvim ecosystem plugins (via vim.pack), all consolidated in this file;
-- mini.statusline lives in plugins/statusline.lua (custom content).
-- Everything uses default config unless noted otherwise.

-- ── Core mini.* plugins ──
local core_plugins = {
    -- Text objects — extends built-in text objects (i) (a)
    "ai",
    -- Comment toggling — gc (toggle), gcc (current line)
    "comment",
    -- Icon provider — file / directory / LSP icons for mini.files and others
    "icons",
    -- Indent scope visualization
    "indentscope",
    -- Move lines / selections — Alt+Up/Down
    "move",
    -- Trailing whitespace highlight and cleanup
    "trailspace",
}

for _, name in ipairs(core_plugins) do
    vim.pack.add({
        { src = "https://github.com/nvim-mini/mini." .. name },
    })
    require("mini." .. name).setup()
end

-- ── Git integration ──
-- Branch / diff data for the statusline (MiniStatusline.section_git).
-- Kept out of the core_plugins loop: the repo is nvim-mini/mini-git (hyphen),
-- and a "mini.git" src would have ".git" parsed as a repo extension, making
-- vim.pack resolve the plugin name to "mini" and clone a nonexistent URL.
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini-git" },
})

require("mini.git").setup()

-- ── Bracket navigation ──
-- Treesitter targets disabled: conflicts with todo-comments' ]t/[t
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.bracketed" },
})

require("mini.bracketed").setup({
    treesitter = { suffix = "" },
})

-- ── Keymap discovery ──
-- Shows available keymaps in a floating window when a prefix key is pressed,
-- using root triggers like which-key. Existing mapping descriptions supply
-- action hints; only virtual <leader> groups need explicit clues.
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.clue" },
})

local miniclue = require("mini.clue")

local clue_triggers = {
    { mode = "n", keys = "<Leader>" },
    { mode = "n", keys = "[" },
    { mode = "n", keys = "]" },
}

local clues = {
    { mode = "n", keys = "<Leader>b", desc = "󰈚 +Buffers" },
    { mode = "n", keys = "<Leader>c", desc = "󰒓 +Config" },
    { mode = "n", keys = "<Leader>f", desc = "󰈞 +Find" },
    { mode = "n", keys = "<Leader>l", desc = "󰘋 +Language" },
    { mode = "n", keys = "<Leader>p", desc = "󰏖 +Packages" },
    { mode = "n", keys = "<Leader>s", desc = "󰤼 +Splits" },
    { mode = "n", keys = "<Leader>t", desc = "󰆍 +Terminal" },
    { mode = "n", keys = "<Leader>u", desc = "󰔡 +Toggles" },
    { mode = "n", keys = "<Leader>w", desc = "󰒩 +Windows" },
    miniclue.gen_clues.square_brackets(),
}

miniclue.setup({
    triggers = clue_triggers,
    clues = clues,

    window = {
        delay = 300,
        config = {
            border = "rounded",
        },
    },
})

-- ── File explorer ──
-- Miller column navigation; replaces netrw as the default file explorer;
-- automatically uses mini.icons for file icons when available.
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.files" },
})

require("mini.files").setup({
    options = {
        -- Replace netrw in scenarios like `:e <dir>`
        use_as_default_explorer = true,
    },
    windows = {
        preview = true, -- show a preview of the file under the cursor
    },
})

-- ── Notification system ──
-- mini.notify owns vim.notify (noice's notify routing is disabled in
-- plugins/noice.lua, so this override survives). The card background is
-- fully opaque (config/colors.lua); width capped at 30% of the editor.
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.notify" },
})

require("mini.notify").setup({
    window = {
        config = {
            focusable = true,
            border = "rounded",
        },
        max_width_share = 0.3,
    },
    -- Progress cards off: noice's lsp.progress mini view already renders LSP
    -- progress (default on); the statusline keeps the attached client names.
    lsp_progress = { enable = false },
})

-- ── Completion and snippets (mini.snippets) ──
-- Native vim.lsp.completion (enabled in config/lsp.lua) provides LSP-driven
-- completion; mini.snippets expands snippets from the JSON snippet files in
-- the snippets/ directory. No third-party completion engine (nvim-cmp,
-- blink.cmp) is needed. Markdown only excludes LSP completion; snippet
-- expansion still works there.
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.snippets" },
})

local mini_snippets = require("mini.snippets")
mini_snippets.setup({
    -- Resolve snippets/<filetype>.json from the config dir (runtimepath)
    snippets = {
        mini_snippets.gen_loader.from_lang(),
    },
    -- Strict expansion: only expand an exact prefix match (or fuzzy on a typed
    -- word); never show the all-snippets picker after a space / at line start,
    -- so <Tab> keeps working for indentation.
    expand = {
        match = function(snips) return mini_snippets.default_match(snips, { pattern_fuzzy = "%S+" }) end,
    },
    -- Session navigation keeps the plugin defaults: <C-l> / <C-h> jump between
    -- fields, <C-j> expands a snippet prefix, <C-q> stops the session (so <C-c>
    -- keeps its usual "exit Insert mode" behavior). Note: in Insert mode
    -- Backspace IS <C-h>, so during a snippet session Backspace jumps to the
    -- previous field instead of deleting — the plugin's default design, kept
    -- deliberately.
    mappings = { jump_prev = "<C-h>", stop = "<C-q>" },
})

-- ── Commands ──

-- :TrimTrailSpace — remove trailing whitespace and trailing blank lines
-- force=true: config.reload re-runs this file and can rebuild it without a
-- "command already exists" error.
vim.api.nvim_create_user_command("TrimTrailSpace", function()
    local view = vim.fn.winsaveview()
    require("mini.trailspace").trim()
    require("mini.trailspace").trim_last_lines()
    vim.fn.winrestview(view)
end, { desc = "Trim trailing whitespace and blank lines in the current buffer", force = true })
