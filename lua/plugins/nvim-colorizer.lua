--  Nvim-Colorizer

---@type LazySpec
return {
  "norcalli/nvim-colorizer.lua",
  config = function()
    require("colorizer").setup({
      -- Attaches to every FileType mode
      "*",
    })
  end,
}
