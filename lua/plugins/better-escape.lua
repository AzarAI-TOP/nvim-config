-- Better Escape

---@type LazySpec
return {
  "max397574/better-escape.nvim",
  opts = {
    timeout = vim.o.timeoutlen, -- after `timeout` passes, you can press the escape key and the plugin will ignore it
    default_mappings = false, -- setting this to false removes all the default mappings
    mappings = {
      -- mode = {
      --     firstkey = {
      --        secondkey = "Escape key", -- make a key press "Escape key"
      --        secondkey = false, -- disable a key
      --     },
      -- }
      i = {
        j = { k = "<ESC>", },
      },
    }
  },
}
