-- Toggleable terminals (akinsho/toggleterm.nvim, via vim.pack)
--
-- Entry points live in config/keymaps.lua, each bound to a fixed terminal id:
--   <leader>th          toggle the main horizontal terminal (id 1)
--   <leader>tv          toggle a vertical terminal (id 2)
--   <leader>tg          toggle lazygit (id 3)
--   <leader>tp          toggle ipython (id 4)
--   <leader>tf / <F2>   toggle a floating terminal (id 5)
--   <F2> (terminal mode) toggle the terminal under the cursor, falling back
--                       to the floating terminal in untagged :terminal buffers
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
    -- Split size must be a function: a single number applies to every
    -- direction, which would cap vertical splits at 15 columns. Horizontal
    -- terminals open 15 rows; vertical ones 40% of the editor width. Floats
    -- size themselves and never consult this option.
    size = function(term)
        if term.direction == "vertical" then return math.floor(vim.o.columns * 0.4) end
        return 15
    end,
    -- Floating terminal border matches the config's rounded border language.
    float_opts = { border = "rounded" },
})
