-- lua/config/neovide.lua
-- Neovide GUI configuration (only loaded when running inside Neovide)

if not vim.g.neovide then return end

local platform = require("config.platform")

-- ── Font ──────────────────────────────────────────────────────────────────
-- 0xProto Nerd Font at 13pt with subpixel antialiasing
vim.o.guifont = "0xProto\\ Nerd\\ Font:h13:#e-subpixelantialias:#h-full"
vim.g.neovide_pixel_geometry = "RGBH" -- required for subpixel antialias (most monitors are RGBH)

-- ── Window appearance ─────────────────────────────────────────────────────
vim.g.neovide_opacity = 0.85
vim.g.neovide_normal_opacity = 0.85
vim.g.neovide_remember_window_size = true
vim.g.neovide_confirm_quit = true
vim.g.neovide_theme = "dark"

if platform.is_windows then
    vim.g.neovide_corner_preference = "round"
    -- Match TokyoNight Moon palette (#222436 bg / #82aaff blue text).
    vim.g.neovide_title_background_color = "222436"
    vim.g.neovide_title_text_color = "82aaff"
end

-- Inner padding for breathing room
vim.g.neovide_padding_top = 5
vim.g.neovide_padding_bottom = 5
vim.g.neovide_padding_left = 5
vim.g.neovide_padding_right = 5

-- ── Cursor animations ─────────────────────────────────────────────────────
vim.g.neovide_cursor_animation_length = 0.15
vim.g.neovide_cursor_trail_size = 1.0
vim.g.neovide_cursor_animate_in_insert_mode = true
vim.g.neovide_cursor_animate_command_line = true
vim.g.neovide_cursor_antialiasing = true

-- Enable every particle mode supported by Neovide 0.16.
vim.g.neovide_cursor_vfx_mode = { "railgun", "torpedo", "pixiedust", "sonicboom", "ripple", "wireframe" }
vim.g.neovide_cursor_vfx_opacity = 200.0

-- ── Floating windows ──────────────────────────────────────────────────────
vim.g.neovide_floating_blur_amount_x = 2.0
vim.g.neovide_floating_blur_amount_y = 2.0
vim.g.neovide_floating_shadow = true

-- ── Scroll animation ──────────────────────────────────────────────────────
vim.g.neovide_scroll_animation_length = 0.3

-- ── Quality of life ───────────────────────────────────────────────────────
vim.g.neovide_hide_mouse_when_typing = true

-- ── IME: auto-toggle for Chinese input ────────────────────────────────────
-- IME off in Normal mode (unimpeded navigation), on in Insert / Cmdline.
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
