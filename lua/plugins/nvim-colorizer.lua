--  Nvim-Colorizer

---@type LazySpec
return {
  "norcalli/nvim-colorizer.lua",
  config = function()
    require("colorizer").setup({
      -- Attaches to every FileType mode (customization link is https://github.com/norcalli/nvim-colorizer.lua?tab=readme-ov-file#customization)
      "*",
    })
  end,
}
