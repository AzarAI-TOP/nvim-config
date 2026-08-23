-- Toggleable terminals (akinsho/toggleterm.nvim, via vim.pack)
--
-- Entry points live in config/keymaps.lua, each bound to a fixed terminal id:
--   <leader>th          toggle the main horizontal terminal (id 1)
--   <leader>tv          toggle a vertical terminal (id 2)
--   <leader>tg          toggle lazygit (id 3)
--   <leader>tp          toggle ipython (id 4)
--   <leader>tf / <F2>   toggle a floating terminal (id 5)
-- The default <C-\> open mapping is disabled so the key surface stays exactly
-- the one defined in keymaps.lua; terminal-mode escape remains <C-\><C-n>
-- and <Esc><Esc>.

vim.pack.add({
    { src = "https://github.com/akinsho/toggleterm.nvim" },
})

require("toggleterm").setup({
    -- No default <C-\> open mapping: every toggle goes through the keymaps
    -- above.
    open_mapping = false,
    -- Split terminals open 15 rows (horizontal) / 15 columns (vertical) tall.
    size = 15,
    -- Floating terminal border matches the config's rounded border language.
    float_opts = { border = "rounded" },
})
