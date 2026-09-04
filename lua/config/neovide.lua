-- Neovide GUI config (only takes effect when running inside Neovide)

if not vim.g.neovide then return end

-- ── Font ──
-- 0xProto Nerd Font, 13pt, subpixel antialiasing
vim.o.guifont = "0xProto\\ Nerd\\ Font:h13:#e-subpixelantialias:#h-full"
vim.g.neovide_pixel_geometry = "RGBH" -- required for subpixel antialiasing (most displays are RGBH)

-- ── Window appearance ──
-- Fully opaque window (no transparency settings).
vim.g.neovide_remember_window_size = true
vim.g.neovide_confirm_quit = true
vim.g.neovide_theme = "dark"

-- Windows title bar: rounded corners, colors from the shared TokyoNight Moon
-- palette (config/colors.lua — single source; Neovide wants hex without "#").
local palette = require("config.colors").palette
vim.g.neovide_corner_preference = "round"
vim.g.neovide_title_background_color = palette.bg:sub(2)
vim.g.neovide_title_text_color = palette.blue:sub(2)

-- Padding around the editor
vim.g.neovide_padding_top = 5
vim.g.neovide_padding_bottom = 5
vim.g.neovide_padding_left = 5
vim.g.neovide_padding_right = 5

-- ── Cursor animation ──
vim.g.neovide_cursor_animation_length = 0.15
vim.g.neovide_cursor_trail_size = 1.0
vim.g.neovide_cursor_animate_in_insert_mode = true
vim.g.neovide_cursor_animate_command_line = true
vim.g.neovide_cursor_antialiasing = true

-- Enable every particle mode supported by Neovide 0.16
vim.g.neovide_cursor_vfx_mode = { "railgun", "torpedo", "pixiedust", "sonicboom", "ripple", "wireframe" }
vim.g.neovide_cursor_vfx_opacity = 200.0

-- ── Floating windows ──
vim.g.neovide_floating_shadow = true

-- ── Scroll animation ──
vim.g.neovide_scroll_animation_length = 0.3

-- ── UX polish ──
vim.g.neovide_hide_mouse_when_typing = true

-- ── Input method: auto-switch for Chinese input ──
-- Normal mode disables the IME (navigation stays uninterrupted); Insert mode
-- enables it; the command line enables it only for search prompts (/ and ?).
vim.g.neovide_input_ime = false
local ime_grp = vim.api.nvim_create_augroup("neovide_ime", { clear = true })
vim.api.nvim_create_autocmd("InsertEnter", {
    group = ime_grp,
    callback = function() vim.g.neovide_input_ime = true end,
})
vim.api.nvim_create_autocmd("InsertLeave", {
    group = ime_grp,
    callback = function() vim.g.neovide_input_ime = false end,
})
vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = ime_grp,
    pattern = { "/", "\\?" },
    callback = function() vim.g.neovide_input_ime = true end,
})
vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = ime_grp,
    pattern = { "/", "\\?" },
    callback = function() vim.g.neovide_input_ime = false end,
})
