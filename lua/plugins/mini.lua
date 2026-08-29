-- mini.nvim ecosystem plugins (via vim.pack), all consolidated in this file;
-- mini.statusline lives in plugins/statusline.lua (custom content).
-- Everything uses default config unless noted otherwise.

-- ── Core mini.* plugins (default config) ──
local core_plugins = {
    -- Comment toggling — gc (toggle), gcc (current line)
    "comment",
    -- Icon provider — file / directory / LSP icons for mini.files and others
    "icons",
    -- Indent scope visualization
    "indentscope",
    -- Move lines / selections — Alt+Up/Down
    "move",
    -- Surround editing — sa (add), sd (delete), sr (replace)
    "surround",
    -- Trailing whitespace highlight and cleanup
    "trailspace",
}

for _, name in ipairs(core_plugins) do
    vim.pack.add({
        { src = "https://github.com/nvim-mini/mini." .. name },
    })
    require("mini." .. name).setup()
end

-- ── mini.ai: text objects ──
-- F (whole function definition) needs the @function.outer/inner captures
-- shipped by nvim-treesitter-textobjects (plugins/treesitter.lua); without
-- them aF / iF silently match nothing.
vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.ai" },
})

require("mini.ai").setup({
    custom_textobjects = {
        F = require("mini.ai").gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
    },
})

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
    { mode = "n", keys = "<leader>" },
    { mode = "n", keys = "[" },
    { mode = "n", keys = "]" },
    -- mini.surround's sa/sd/sr/... prefix (its mappings carry descriptions)
    { mode = "n", keys = "s" },
    { mode = "x", keys = "s" },
}

local clues = {
    { mode = "n", keys = "<leader>b", desc = "󰈚 +Buffers" },
    { mode = "n", keys = "<leader>c", desc = "󰒓 +Config" },
    { mode = "n", keys = "<leader>f", desc = "󰈞 +Find" },
    { mode = "n", keys = "<leader>l", desc = "󰘋 +Language" },
    { mode = "n", keys = "<leader>p", desc = "󰏖 +Packages" },
    { mode = "n", keys = "<leader>s", desc = "󰤼 +Splits" },
    { mode = "n", keys = "<leader>t", desc = "󰆍 +Terminal" },
    { mode = "n", keys = "<leader>u", desc = "󰔡 +Toggles" },
    { mode = "n", keys = "<leader>S", desc = "󰗀 +Sessions" },
    { mode = "n", keys = "s", desc = "󰅱 +Surround" },
    { mode = "x", keys = "s", desc = "󰅱 +Surround" },
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
            -- Focusable cards would join <C-w>w window rotation, trapping the
            -- cycle inside a toast. Content stays reachable via
            -- MiniNotify.show_history() and the <leader>fn picker.
            focusable = false,
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
