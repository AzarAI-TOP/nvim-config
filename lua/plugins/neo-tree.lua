-- Neo-tree

---@type LazySpec
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  lazy = false, -- neo-tree will lazily load itself
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons", -- optional, but recommended
  },

  opts = {
    close_if_last_window = true,
    source_selector = {
      winbar = true,
    },
    window = {
      position = "left",
      width = 30,
      mapping_options = {
        noremap = true,
        nowait = true,
      },
      mappings = {
        ["<space>"] = {
          "toggle_node",
          nowait = true, -- disable `nowait` if you have existing combos starting with this char that you want to use
        },
      },
    },
  },
}
