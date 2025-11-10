-- This file is for setting nvim's key mappings
-- Some of these mappings is copied from LazyVim/LazyVim

local map = vim.keymap.set

-- Better up/down
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })
map({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })

-- Quit
map("n", "<leader>qq", "<Cmd>qa<CR>", { desc = "Quit All" })

-- Save file
map({ "i", "x", "n", "s" }, "<C-s>", "<Cmd>w<CR><esc>", { desc = "Save File" })

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
map({ "n", "o" }, "<Leader>F", function() require("hop").hint_char1() end, { desc = "Hop move in this screen" })
map({ "n", "o" }, "<Leader>f", function() require("hop").hint_char1 { current_line_only = true } end,
  { desc = "Hop move in this line" })

-- Todo-Comments
map("n", "]t", function() require("todo-comments").jump_next() end, { desc = "Go to the next todo comments" })
map("n", "[t", function() require("todo-comments").jump_prev() end, { desc = "Go to the previous todo comments" })
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
map("n", "<Leader>la", vim.lsp.buf.code_action, { desc = "Rename the symbol" })
map("n", "<Leader>lf", function()
  require("conform").format({
    lsp_format = "fallback",
    timeout_ms = 1000,
  })
end, { desc = "Format the code" })
map("n", "<Leader>lr", vim.lsp.buf.rename, { desc = "Rename the symbol" })
map("n", "<Leader>lR", vim.lsp.buf.references, { desc = "References" })
map("n", "<Leader>ld", vim.lsp.buf.definition, { desc = "Definition" })
map("n", "<Leader>lD", vim.lsp.buf.declaration, { desc = "Declaration" })

-- Diagnotic
map('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Go to the next diagnostic" })
map('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Go to the next diagnostic" })
map("n", "<Leader>d", function() vim.diagnostic.open_float() end, { desc = "Open diagnostic window" })
