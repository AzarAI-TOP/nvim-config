-- Conform

---@type LazySpec
return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      python = { "isort", "black" },
      lua = { "stylua" },
      c = { "clang-format" },
      cpp = { "clang-format" },
      markdown = { "prettierd" },
      toml = { "taplo" },
      json = { "prettierd" },
      jsonc = { "prettierd" },
    },
  },
}
