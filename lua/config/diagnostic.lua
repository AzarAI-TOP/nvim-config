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
  virtual_text = false,
  virtual_lines = false,
  update_in_insert = false,
  float = {
    header = "Diagnostic",
    border = "rounded",
  },
})
