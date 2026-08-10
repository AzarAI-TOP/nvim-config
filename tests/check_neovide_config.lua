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
check(type(vim.g.neovide_cursor_vfx_mode) == "table", "cursor VFX mode must be a table")
check(#vim.g.neovide_cursor_vfx_mode == 6, "all six cursor VFX modes must be enabled")

local cmdline_enter = vim.api.nvim_get_autocmds({ group = "neovide_ime", event = "CmdlineEnter" })
local cmdline_leave = vim.api.nvim_get_autocmds({ group = "neovide_ime", event = "CmdlineLeave" })
check(#cmdline_enter == 2, "IME must register literal / and ? CmdlineEnter patterns")
check(#cmdline_leave == 2, "IME must register literal / and ? CmdlineLeave patterns")

local enter_patterns = {}
for _, autocmd in ipairs(cmdline_enter) do
    enter_patterns[autocmd.pattern] = true
end
check(enter_patterns["/"] == true, "literal / CmdlineEnter pattern missing")
check(enter_patterns["\\?"] == true, "escaped literal ? CmdlineEnter pattern missing")

for _, search_type in ipairs({ "/", "?" }) do
    vim.g.neovide_input_ime = false
    vim.api.nvim_exec_autocmds("CmdlineEnter", { pattern = search_type })
    check(vim.g.neovide_input_ime == true, "IME did not enable for " .. search_type .. " search")
    vim.api.nvim_exec_autocmds("CmdlineLeave", { pattern = search_type })
    check(vim.g.neovide_input_ime == false, "IME did not disable after " .. search_type .. " search")
end

for _, non_search_type in ipairs({ ":", "=", "@", "-" }) do
    vim.g.neovide_input_ime = false
    vim.api.nvim_exec_autocmds("CmdlineEnter", { pattern = non_search_type })
    check(vim.g.neovide_input_ime == false, "IME must stay disabled for " .. non_search_type .. " commands")
end

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
