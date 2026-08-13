-- 平台检测、平台相关键位与 Neovide 设置。

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- ── 平台检测 ──

local platform = require("config.platform")
local function fake_has(enabled)
    return function(feature) return enabled[feature] and 1 or 0 end
end

local windows = platform.detect({
    has = fake_has({ win32 = true }),
    -- Git Bash 与 CI 可能把 DISPLAY 泄漏给原生 Windows 进程。
    env = { DISPLAY = ":0" },
    uname_release = "Windows_NT",
})
check(windows.is_windows and windows.name == "windows", "Windows 检测失败")
check(not windows.is_remote and not windows.has_display, "Windows 标志不一致")

local fedora_wayland = platform.detect({
    has = fake_has({ linux = true }),
    env = { WAYLAND_DISPLAY = "wayland-0" },
    uname_release = "6.15.0-200.fc42.x86_64",
})
check(fedora_wayland.is_linux and fedora_wayland.name == "linux", "Fedora 检测失败")
check(fedora_wayland.is_wayland and fedora_wayland.has_display, "Fedora Wayland 检测失败")
check(not fedora_wayland.is_remote, "Fedora 桌面不得视为远端")

local wsl = platform.detect({
    has = fake_has({ linux = true }),
    env = { WSL_DISTRO_NAME = "FedoraLinux-42" },
    uname_release = "6.6.87.2-microsoft-standard-WSL2",
})
check(wsl.is_wsl and wsl.is_remote and wsl.name == "wsl", "WSL 检测失败")

local ubuntu_ssh = platform.detect({
    has = fake_has({ linux = true }),
    env = { SSH_CONNECTION = "192.0.2.1 12345 192.0.2.2 22" },
    uname_release = "6.8.0-generic",
})
check(ubuntu_ssh.is_linux and ubuntu_ssh.is_ssh, "Ubuntu SSH 检测失败")
check(ubuntu_ssh.is_remote and not ubuntu_ssh.has_display, "Ubuntu SSH 标志不一致")

local empty_remote_env = platform.detect({
    has = fake_has({ linux = true }),
    env = { WSL_DISTRO_NAME = "", WSL_INTEROP = "", SSH_CONNECTION = "", SSH_CLIENT = "", SSH_TTY = "" },
    uname_release = "6.8.0-generic",
})
check(not empty_remote_env.is_remote, "空的 WSL/SSH 变量不得把本地会话标记为远端")

-- ── 平台相关键位 ──

if vim.fn.has("win32") == 1 then
    check(vim.fn.maparg("<leader>W", "n") == "", "Windows 不得注册 sudo 保存映射")
end

local config_mapping = vim.fn.maparg("<leader>fc", "n", false, true)
check(type(config_mapping.callback) == "function", "配置选择器必须使用带运行时 stdpath 的回调")
if type(config_mapping.callback) == "function" then
    local fzf = require("fzf-lua")
    local original_files = fzf.files
    local captured
    fzf.files = function(opts) captured = opts end
    local ok, err = pcall(config_mapping.callback)
    fzf.files = original_files
    check(ok, "配置选择器回调失败：" .. tostring(err))
    check(captured and captured.cwd == vim.fn.stdpath("config"), "配置选择器 cwd 必须等于 stdpath('config')")
end

-- ── Neovide ──

package.loaded["config.neovide"] = nil
vim.g.neovide = true
require("config.neovide")

check(vim.o.guifont:find("0xProto", 1, true) ~= nil, "Neovide 字体不是 0xProto")
check(vim.g.neovide_opacity == 0.85, "Neovide 不透明度不匹配")
check(
    type(vim.g.neovide_cursor_vfx_mode) == "table" and #vim.g.neovide_cursor_vfx_mode == 6,
    "六种光标粒子模式必须全部启用"
)

local cmdline_enter = vim.api.nvim_get_autocmds({ group = "neovide_ime", event = "CmdlineEnter" })
check(#cmdline_enter == 2, "IME 必须注册字面量 / 和 ? 两个 CmdlineEnter 模式")
for _, search_type in ipairs({ "/", "?" }) do
    vim.g.neovide_input_ime = false
    vim.api.nvim_exec_autocmds("CmdlineEnter", { pattern = search_type })
    check(vim.g.neovide_input_ime == true, "IME 未对 " .. search_type .. " 搜索启用")
    vim.api.nvim_exec_autocmds("CmdlineLeave", { pattern = search_type })
    check(vim.g.neovide_input_ime == false, "IME 未在 " .. search_type .. " 搜索后关闭")
end
for _, non_search_type in ipairs({ ":", "=", "@", "-" }) do
    vim.g.neovide_input_ime = false
    vim.api.nvim_exec_autocmds("CmdlineEnter", { pattern = non_search_type })
    check(vim.g.neovide_input_ime == false, "IME 对 " .. non_search_type .. " 命令必须保持关闭")
end
if platform.is_windows then
    check(vim.g.neovide_corner_preference == "round", "缺少 Windows 圆角")
    check(vim.g.neovide_title_background_color == "222436", "Windows 标题栏颜色不匹配")
end

if #failures > 0 then
    io.stderr:write("PLATFORM_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("PLATFORM_CHECK_OK platform=" .. platform.name .. "\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
