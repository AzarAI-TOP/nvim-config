local platform = require("config.platform")
local failures = {}

local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

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

if #failures > 0 then
    io.stderr:write("PLATFORM_DETECTION_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("PLATFORM_DETECTION_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
