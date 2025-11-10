-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- add your plugins here
    {import = "../plugins"}
  },
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "tokyonight-moon" } },
  -- automatically check for plugin updates
  checker = {
    enabled = true,
    notify = false,
  },
  -- automatically check for config file changes and reload the ui
  change_detection = {
    enabled = true,
    notify = false, -- get a notification when changes are found
  },
})

