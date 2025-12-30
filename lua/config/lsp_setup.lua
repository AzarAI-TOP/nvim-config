-- LSP Setup

local lsp_dir = vim.fn.stdpath("config") .. "/lsp"
local lsp_servers = {}

if vim.fn.isdirectory(lsp_dir) == 1 then
  for _, file in ipairs(vim.fn.readdir(lsp_dir)) do
    if file:match("%.lua$") and file ~= "init.lua" then
      local server_name = file:gsub("%.lua$", "")
      table.insert(lsp_servers, server_name)
    end
  end
end

vim.lsp.enable(lsp_servers)


-- Diagnostic configurations
vim.diagnostic.config({
  signs = {
    text = {
      ERROR = "󰅙",
      WARN = "",
      INFO = "󰋼",
      HINT = "󰌵",
    },
  },
  underline = true,
  virtual_text = {
    spacing = 4,
    source = "if_many",
    prefix = "●",
  },
  virtual_lines = false,
  update_in_insert = false,
  float = {
    header = "Diagnostic",
    border = "rounded",
  },
})
