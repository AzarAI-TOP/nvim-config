-- Nvim-Lualine

---@type LazySpec
return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    theme = "tokyonight",
    disabled_filetypes = {
      statusline = { "neo-tree" },
      tabline = { "neo-tree" },
      winbar = { "neo-tree" },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = {
        "branch",
        "diff",
        "diagnostics",
      },

      lualine_c = { "filename" },
      lualine_x = { "encoding", "lsp_status", "filetype" },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { "filename" },
      lualine_x = { "location" },
      lualine_y = {},
      lualine_z = {},
    },

    extensions = { "neo-tree" },
  },
}
