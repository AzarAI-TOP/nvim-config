-- Platform detection, platform-dependent keymaps, and Neovide settings.

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- --- Platform detection ------------------------------------------------------

local platform = require("config.platform")
local function fake_has(enabled)
    return function(feature) return enabled[feature] and 1 or 0 end
end

local windows = platform.detect({
    has = fake_has({ win32 = true }),
    -- Git Bash and CI may leak DISPLAY into native Windows processes.
    env = { DISPLAY = ":0" },
    uname_release = "Windows_NT",
})
check(windows.is_windows and windows.name == "windows", "Windows detection failed")
check(not windows.is_remote and not windows.has_display, "Windows flags are inconsistent")

local fedora_wayland = platform.detect({
    has = fake_has({ linux = true }),
    env = { WAYLAND_DISPLAY = "wayland-0" },
    uname_release = "6.15.0-200.fc42.x86_64",
})
check(fedora_wayland.is_linux and fedora_wayland.name == "linux", "Fedora detection failed")
check(fedora_wayland.is_wayland and fedora_wayland.has_display, "Fedora Wayland detection failed")
check(not fedora_wayland.is_remote, "Fedora desktop must not be remote")

local wsl = platform.detect({
    has = fake_has({ linux = true }),
    env = { WSL_DISTRO_NAME = "FedoraLinux-42" },
    uname_release = "6.6.87.2-microsoft-standard-WSL2",
})
check(wsl.is_wsl and wsl.is_remote and wsl.name == "wsl", "WSL detection failed")

local ubuntu_ssh = platform.detect({
    has = fake_has({ linux = true }),
    env = { SSH_CONNECTION = "192.0.2.1 12345 192.0.2.2 22" },
    uname_release = "6.8.0-generic",
})
check(ubuntu_ssh.is_linux and ubuntu_ssh.is_ssh, "Ubuntu SSH detection failed")
check(ubuntu_ssh.is_remote and not ubuntu_ssh.has_display, "Ubuntu SSH flags are inconsistent")

local empty_remote_env = platform.detect({
    has = fake_has({ linux = true }),
    env = { WSL_DISTRO_NAME = "", WSL_INTEROP = "", SSH_CONNECTION = "", SSH_CLIENT = "", SSH_TTY = "" },
    uname_release = "6.8.0-generic",
})
check(not empty_remote_env.is_remote, "empty WSL/SSH variables must not mark a local session remote")

-- --- Platform-dependent keymaps ----------------------------------------------

if vim.fn.has("win32") == 1 then
    check(vim.fn.maparg("<leader>W", "n") == "", "Windows must not register the sudo-save mapping")
end

local config_mapping = vim.fn.maparg("<leader>fc", "n", false, true)
check(type(config_mapping.callback) == "function", "config picker must use a callback with a runtime stdpath")
if type(config_mapping.callback) == "function" then
    local fzf = require("fzf-lua")
    local original_files = fzf.files
    local captured
    fzf.files = function(opts) captured = opts end
    local ok, err = pcall(config_mapping.callback)
    fzf.files = original_files
    check(ok, "config picker callback failed: " .. tostring(err))
    check(captured and captured.cwd == vim.fn.stdpath("config"), "config picker cwd must equal stdpath('config')")
end

-- --- Neovide -----------------------------------------------------------------

package.loaded["config.neovide"] = nil
vim.g.neovide = true
require("config.neovide")

check(vim.o.guifont:find("0xProto", 1, true) ~= nil, "Neovide font is not 0xProto")
check(vim.g.neovide_opacity == 0.85, "Neovide opacity mismatch")
check(
    type(vim.g.neovide_cursor_vfx_mode) == "table" and #vim.g.neovide_cursor_vfx_mode == 6,
    "all six cursor VFX modes must be enabled"
)

local cmdline_enter = vim.api.nvim_get_autocmds({ group = "neovide_ime", event = "CmdlineEnter" })
check(#cmdline_enter == 2, "IME must register literal / and ? CmdlineEnter patterns")
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
if platform.is_windows then
    check(vim.g.neovide_corner_preference == "round", "Windows rounded corners are missing")
    check(vim.g.neovide_title_background_color == "222436", "Windows title color mismatch")
end

if #failures > 0 then
    io.stderr:write("PLATFORM_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("PLATFORM_CHECK_OK platform=" .. platform.name .. "\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
