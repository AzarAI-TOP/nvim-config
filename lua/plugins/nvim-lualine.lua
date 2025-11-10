-- Nvim-Lualine

---@type Lazy.spec
return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  opts = {
    theme = "tokyonight",
    disabled_filetypes = {
      statusline = { 'neo-tree' },
      tabline = { 'neo-tree' },
      winbar = { 'neo-tree' },
    },
    sections = {
      lualine_a = { 'mode' },
      lualine_b = {
        'branch',
        'diff',
        'diagnostics',
      },

      lualine_c = { 'filename' },
      lualine_x = { 'lsp_status', 'encoding', 'filetype' },
      lualine_y = { 'progress' },
      lualine_z = { 'location' }
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { 'filename' },
      lualine_x = { 'location' },
      lualine_y = {},
      lualine_z = {}
    },
    tabline = {
      lualine_a = {
        {
          'buffers',
          max_length = vim.o.columns * 9 / 10,
          use_mode_colors = false,
        }
      },
      lualine_b = {},
      lualine_c = {},
      lualine_x = {},
      lualine_y = {},
      lualine_z = { 'lsp_status' },
    },
    extensions = { "neo-tree" },
  },
}
