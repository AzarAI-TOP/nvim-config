-- FTerm

---@type LazySpec
return {
  "numToStr/FTerm.nvim",
  config = function(_, opts)
    local fterm = require("FTerm")
    vim.keymap.set("n", "<Leader>tt", fterm.toggle, { desc = "Toggle terminal" })
    -- Custom several terminals
    -- Lazygit
    ---@diagnostic disable-next-line: missing-fields
    local fterm_lazygit = fterm:new({
      ft = "fterm_lazygit",
      cmd = "lazygit",
      ---@diagnostic disable-next-line: missing-fields
      dimensions = {
        height = 0.8,
        width = 0.8,
      },
    })
    vim.keymap.set("n", "<Leader>tl", function()
      fterm_lazygit:toggle()
    end, { desc = "Toggle terminal of Lazygit" })

    -- Python
    ---@diagnostic disable-next-line: missing-fields
    local fterm_python = fterm:new({
      ft = "fterm_python",
      cmd = "python",
      ---@diagnostic disable-next-line: missing-fields
      dimensions = {
        height = 0.8,
        width = 0.8,
      },
    })
    vim.keymap.set("n", "<Leader>tp", function()
      fterm_python:toggle()
    end, { desc = "Toggle terminal of Python" })

    -- Btop
    ---@diagnostic disable-next-line: missing-fields
    local fterm_btop = fterm:new({
      ft = "fterm_btop",
      cmd = "btop",
      ---@diagnostic disable-next-line: missing-fields
      dimensions = {
        height = 0.8,
        width = 0.9,
      },
    })
    vim.keymap.set("n", "<Leader>tb", function()
      fterm_btop:toggle()
    end, { desc = "Toggle terminal of Btop" })

    -- Configurate FTerm
    opts.border = "rounded"
    opts.dimensions = {
      height = 0.8,
      width = 0.8,
    }

    fterm.setup(opts)
  end,
}
