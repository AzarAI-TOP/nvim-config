-- Mini-Notify

---@type LazySpec
return {
  "nvim-mini/mini.notify",
  version = "*",
  config = function(_, opts)
    local mini_notify = require("mini.notify")

    -- Setup
    mini_notify.setup({
      lsp_progress = {
        enable = true,
        -- Notification level
        level = "INFO",
        -- Duration (in ms) of how long last message should show
        duration_last = 1000,
      },

      window = {
        -- Maximum window width ratio (between 0 ~ 1)
        max_width_share = 0.382,
        -- Transparency ratio (between 0(disabled) ~ 100(fully Transparent))
        winblend = 25,
      },
    })

    -- Wrap the origin nvim notify
    vim.notify = mini_notify.make_notify()
  end,
}
