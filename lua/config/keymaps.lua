-- This file is for setting nvim's key mappings
-- Some of these mappings is copied from LazyVim/LazyVim

local map = require("config.utils").default_keymap

-- Better up/down of cursor motion
map("nx", "j", "v:count == 0 ? 'gj' : 'j'", "Down", { expr = true })
map("nx", "<Down>", "v:count == 0 ? 'gj' : 'j'", "Down", { expr = true })
map("nx", "k", "v:count == 0 ? 'gk' : 'k'", "Up", { expr = true })
map("nx", "<Up>", "v:count == 0 ? 'gk' : 'k'", "Up", { expr = true })

-- Quit
map("n", "<leader>qq", "<Cmd>qa<CR>", "Quit All")
map("n", "<C-Q>", "<Cmd>qa<CR>", "Quit All")

-- Save file
map("inxs", "<C-S>", "<Cmd>w<CR><esc>", "Save File")

-- Undo
map("n", "U", "<C-R>", "Redo")

-- Buffers
map("n", "[b", "<Cmd>bprevious<CR>", "Prev buffer")
map("n", "]b", "<Cmd>bnext<CR>", "Next buffer")
map("n", "<Leader>bc", "<Cmd>bd<CR>", "Close buffer")

-- Lazy
map("n", "<Leader>pl", "<Cmd>Lazy<CR>", "Open Lazy")
map("n", "<Leader>pu", "<Cmd>Lazy<CR>", "Update plugins")
map("n", "<Leader>pc", "<Cmd>Lazy check<CR>", "Check plugins' updates")
map("n", "<Leader>pC", "<Cmd>Lazy clean<CR>", "Clean no-needed plugins")

-- Comment
map("n", "<Leader>/", "gcc", "Toggle comment", { noremap = false })
map("ox", "<Leader>/", "gc", "Toggle comment", { noremap = false })

-- Hop
map("nox", "<Leader>J", function()
  require("hop").hint_char1()
end, "Hop move in this screen")
map("nox", "<Leader>j", function()
  require("hop").hint_char1({ current_line_only = true })
end, "Hop move in this line")

-- Todo-Comments
map("n", "]t", require("todo-comments").jump_next, "Go to the next todo comments")
map("n", "[t", require("todo-comments").jump_prev, "Go to the previous todo comments")
map("n", "<F5>", "<Cmd>TodoQuickFix<CR>", "Show all todos in the project")
map("n", "<F4>", "<Cmd>TodoLocList<CR>", "Show all todos in the buffer")

-- Directory Explorer
map("n", "<Leader>e", "<Cmd>Neotree toggle<CR>", "Toggle directory explorer")

-- LSP
map("n", "K", function()
  vim.lsp.buf.hover({
    border = "rounded",
    width = 60,
    height = 15,
  })
end, "Hover the word")
map("n", "<Leader>la", vim.lsp.buf.code_action, "Code action")
map("n", "<Leader>lf", function()
  ---@diagnostic disable-next-line
  require("conform").format({
    lsp_format = "fallback",
    timeout_ms = 1000,
  })
end, "Format the code")
map("n", "<Leader>lr", vim.lsp.buf.rename, "Rename the symbol")
map("n", "<Leader>lR", require("telescope.builtin").lsp_references, "References")
map("n", "<Leader>ld", vim.lsp.buf.declaration, "Declaration")
map("n", "<Leader>lD", vim.lsp.buf.definition, "Definition")
map("n", "<Leader>ls", require("telescope.builtin").lsp_document_symbols, "List symbols in current buffer")
map("n", "<Leader>lS", require("telescope.builtin").lsp_workspace_symbols, "List symbols in current workspace")

-- Diagnotic
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, "Go to the next diagnostic")
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, "Go to the next diagnostic")
map("n", "<Leader>d", vim.diagnostic.open_float, "Open diagnostic window under cursor")

-- Telescope
map("n", "<Leader>ff", require("telescope.builtin").find_files, "Find files")
map("n", "<Leader>fw", require("telescope.builtin").live_grep, "Live grep")
map("n", "<Leader>fa", function()
  require("telescope.builtin").find_files({
    prompt_title = "Config files",
    cwd = vim.fn.stdpath("config"),
  })
end, "Find files")
map("n", "<Leader>fh", require("telescope.builtin").help_tags, "Help tags")
map("n", "<Leader>fk", require("telescope.builtin").keymaps, "Keymaps")
map("n", "<Leader>fr", require("telescope.builtin").registers, "Registers")
map("n", "<Leader>fd", require("telescope.builtin").diagnostics, "Diagnostics")

-- Git
map("n", "<Leader>gc", require("telescope.builtin").git_commits, "Git commits")
