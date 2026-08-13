-- Neovide GUI 配置（仅在 Neovide 内运行时生效）

if not vim.g.neovide then return end

local platform = require("config.platform")

-- ── 字体 ──
-- 0xProto Nerd Font，13pt，亚像素抗锯齿
vim.o.guifont = "0xProto\\ Nerd\\ Font:h13:#e-subpixelantialias:#h-full"
vim.g.neovide_pixel_geometry = "RGBH" -- 亚像素抗锯齿需要（多数显示器为 RGBH）

-- ── 窗口外观 ──
vim.g.neovide_opacity = 0.85
vim.g.neovide_normal_opacity = 0.85
vim.g.neovide_remember_window_size = true
vim.g.neovide_confirm_quit = true
vim.g.neovide_theme = "dark"

if platform.is_windows then
    vim.g.neovide_corner_preference = "round"
    -- 与 TokyoNight Moon 调色板匹配（背景 #222436 / 文字 #82aaff）
    vim.g.neovide_title_background_color = "222436"
    vim.g.neovide_title_text_color = "82aaff"
end

-- 内边距留白
vim.g.neovide_padding_top = 5
vim.g.neovide_padding_bottom = 5
vim.g.neovide_padding_left = 5
vim.g.neovide_padding_right = 5

-- ── 光标动画 ──
vim.g.neovide_cursor_animation_length = 0.15
vim.g.neovide_cursor_trail_size = 1.0
vim.g.neovide_cursor_animate_in_insert_mode = true
vim.g.neovide_cursor_animate_command_line = true
vim.g.neovide_cursor_antialiasing = true

-- 启用 Neovide 0.16 支持的全部粒子模式
vim.g.neovide_cursor_vfx_mode = { "railgun", "torpedo", "pixiedust", "sonicboom", "ripple", "wireframe" }
vim.g.neovide_cursor_vfx_opacity = 200.0

-- ── 浮动窗口 ──
vim.g.neovide_floating_blur_amount_x = 2.0
vim.g.neovide_floating_blur_amount_y = 2.0
vim.g.neovide_floating_shadow = true

-- ── 滚动动画 ──
vim.g.neovide_scroll_animation_length = 0.3

-- ── 体验优化 ──
vim.g.neovide_hide_mouse_when_typing = true

-- ── 输入法：中文输入自动切换 ──
-- 普通模式关闭输入法（导航不受干扰），插入 / 命令行模式开启。
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
