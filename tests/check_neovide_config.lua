package.loaded["config.neovide"] = nil
vim.g.neovide = true
require("config.neovide")

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

check(vim.o.guifont:find("0xProto", 1, true) ~= nil, "Neovide font is not 0xProto")
check(vim.g.neovide_opacity == 0.85, "Neovide opacity mismatch")
check(vim.g.neovide_remember_window_size == true, "Neovide window size must persist")
check(type(vim.g.neovide_cursor_vfx_mode) == "table", "Neovide VFX must be a list")
check(#vim.g.neovide_cursor_vfx_mode == 6, "All six Neovide VFX modes must be enabled")

if require("config.platform").is_windows then
    check(vim.g.neovide_corner_preference == "round", "Windows rounded corners are missing")
    check(vim.g.neovide_title_background_color == "222436", "Windows title color mismatch")
end

if #failures > 0 then
    io.stderr:write("NEOVIDE_CONFIG_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("NEOVIDE_CONFIG_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
