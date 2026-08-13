-- mini.nvim ecosystem plugins (via vim.pack), all consolidated in this file.
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
-- covering every <leader> group in this config.
-- The host-clipboard copies <leader>y / <leader>Y are only registered on remote
-- platforms (WSL/SSH), so they only appear as hints there.
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.clue" },
})

local miniclue = require("mini.clue")

local clue_triggers = {
    { mode = "n", keys = "<leader>b", desc = "+Buffers" },
    { mode = "n", keys = "<leader>c", desc = "+Config" },
    { mode = "n", keys = "<leader>l", desc = "+Language" },
    { mode = "n", keys = "<leader>f", desc = "+Find" },
    { mode = "n", keys = "<leader>w", desc = "+Windows" },
    { mode = "n", keys = "<leader>t", desc = "+Toggles" },
    { mode = "n", keys = "<leader>p", desc = "+Packages" },
    { mode = "n", keys = "<leader>s", desc = "+Splits" },
    { mode = "n", keys = "<leader>e", desc = "File explorer" },
    { mode = "n", keys = "<leader>nh", desc = "Clear search highlight" },
    { mode = "n", keys = "<leader>q", desc = "Quit" },
    { mode = "n", keys = "<leader>Q", desc = "Quit all" },
}
if require("config.platform").is_remote then
    table.insert(clue_triggers, { mode = "n", keys = "<leader>y", desc = "Copy to host clipboard" })
    table.insert(clue_triggers, { mode = "n", keys = "<leader>Y", desc = "Copy line to host clipboard" })
end

miniclue.setup({
    triggers = clue_triggers,

    clues = {
        miniclue.gen_clues.builtin_completion(),
    },

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
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.notify" },
})

require("mini.notify").setup({
    window = {
        config = {
            focusable = true,
        },
    },
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
