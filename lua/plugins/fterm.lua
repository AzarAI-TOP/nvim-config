-- FTerm

---@type LazySpec
return {
  "numToStr/FTerm.nvim",
  config = function(_, opts)
    local fterm = require("FTerm")
    local map = require("config.utils").default_keymap

    --  Default terminal
    map("nt", "<F1>", fterm.toggle, "Toggle terminal")
    map("n", "<Leader>tt", fterm.toggle, "Toggle terminal")

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

    map("n", "<Leader>tl", function()
      fterm_lazygit:toggle()
    end, "Toggle terminal of Lazygit")

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
    map("n", "<Leader>tp", function()
      fterm_python:toggle()
    end, "Toggle terminal of Python")

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
    map("n", "<Leader>tb", function()
      fterm_btop:toggle()
    end, "Toggle terminal of Btop")

    -- Configurate FTerm
    opts.border = "rounded"
    opts.dimensions = {
      height = 0.8,
      width = 0.8,
    }

    fterm.setup(opts)
  end,
}
