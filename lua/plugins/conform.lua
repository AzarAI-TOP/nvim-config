-- Conform

---@type LazySpec
return {
  'stevearc/conform.nvim',
  opts = {
    formatters_by_ft = {
      python = { "isort", "black" },
      lua = { "stylua" },
    },
  },
}
