-- Nvim-Notify

---@type LazySpec
return {
  "rcarriga/nvim-notify",
  config = function()
    local notify = require("notify")
    ---@diagnostic disable-next-line:undefined-field
    notify.setup({
      stages = "fade_in_slide_out",
      -- background_colour = "#2E3440",
      timeout = 3000,
    })
    -- Wrap the default notify function
    vim.notify = notify
  end,
}
