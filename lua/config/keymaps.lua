-- This file is for setting nvim's key mappings
-- Some of these mappings is copied from LazyVim/LazyVim

local map = vim.keymap.set

-- Better up/down of changing origin line motions to visible ones
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })
map({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })

-- Quit
map("n", "<leader>qq", "<Cmd>qa<CR>", { desc = "Quit All" })

-- Save file
map({ "i", "x", "n", "s" }, "<C-s>", "<Cmd>w<CR><esc>", { desc = "Save File" })

-- Undo
map("n", "U", "<C-R>", { desc = "Redo" })

-- Buffers
map("n", "[b", "<Cmd>bprevious<CR>", { desc = "Prev buffer" })
map("n", "]b", "<Cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<Leader>c", "<Cmd>bd<CR>", { desc = "Close buffer" })

-- Lazy
map("n", "<Leader>pl", "<Cmd>Lazy<CR>", { desc = "Open Lazy" })
map("n", "<Leader>pu", "<Cmd>Lazy<CR>", { desc = "Update plugins" })
map("n", "<Leader>pc", "<Cmd>Lazy check<CR>", { desc = "Check plugins' updates" })
map("n", "<Leader>pC", "<Cmd>Lazy clean<CR>", { desc = "Clean no-needed plugins" })

-- Comment
map("n", "<Leader>/", "gcc", { desc = "Toggle comment", remap = true })
map({ "o", "x" }, "<Leader>/", "gc", { desc = "Toggle comment", remap = true })

-- Hop
map({ "n", "o", "x" }, "<Leader>J", function()
  require("hop").hint_char1()
end, { desc = "Hop move in this screen" })
map({ "n", "o", "x" }, "<Leader>j", function()
  require("hop").hint_char1({ current_line_only = true })
end, { desc = "Hop move in this line" })

-- Todo-Comments
map("n", "]t", require("todo-comments").jump_next, { desc = "Go to the next todo comments" })
map("n", "[t", require("todo-comments").jump_prev, { desc = "Go to the previous todo comments" })
map("n", "<F5>", "<Cmd>TodoQuickFix<CR>", { desc = "Show all todos in the project" })
map("n", "<F4>", "<Cmd>TodoLocList<CR>", { desc = "Show all todos in the buffer" })

-- Directory Explorer
map("n", "<Leader>e", "<Cmd>Neotree toggle<CR>", { desc = "Toggle directory explorer" })

-- LSP
map("n", "K", function()
  vim.lsp.buf.hover({
    border = "rounded",
    width = 60,
    height = 15,
  })
end, { desc = "Hover the word" })
map("n", "<Leader>la", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<Leader>lf", function()
  ---@diagnostic disable-next-line
  require("conform").format({
    lsp_format = "fallback",
    timeout_ms = 1000,
  })
end, { desc = "Format the code" })
map("n", "<Leader>lr", vim.lsp.buf.rename, { desc = "Rename the symbol" })
map("n", "<Leader>lR", require("telescope.builtin").lsp_references, { desc = "References" })
map("n", "<Leader>ld", vim.lsp.buf.declaration, { desc = "Declaration" })
map("n", "<Leader>lD", vim.lsp.buf.definition, { desc = "Definition" })
map("n", "<Leader>ls", require("telescope.builtin").lsp_document_symbols, { desc = "List symbols in current buffer" })
map(
  "n",
  "<Leader>lS",
  require("telescope.builtin").lsp_workspace_symbols,
  { desc = "List symbols in current workspace" }
)

-- Diagnotic
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Go to the next diagnostic" })
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Go to the next diagnostic" })
map("n", "<Leader>d", vim.diagnostic.open_float, { desc = "Open diagnostic window under cursor" })

-- Telescope
map("n", "<Leader>ff", require("telescope.builtin").find_files, { desc = "Find files" })
map("n", "<Leader>fw", require("telescope.builtin").live_grep, { desc = "Live grep" })
map("n", "<Leader>fa", function()
  require("telescope.builtin").find_files({
    prompt_title = "Config files",
    cwd = vim.fn.stdpath("config"),
  })
end, { desc = "Find files" })
map("n", "<Leader>fh", require("telescope.builtin").help_tags, { desc = "Help tags" })
map("n", "<Leader>fk", require("telescope.builtin").keymaps, { desc = "Keymaps" })
map("n", "<Leader>fr", require("telescope.builtin").registers, { desc = "Registers" })
map("n", "<Leader>fd", require("telescope.builtin").diagnostics, { desc = "Diagnostics" })

-- Git
map("n", "<Leader>gc", require("telescope.builtin").git_commits, { desc = "Git commits" })
