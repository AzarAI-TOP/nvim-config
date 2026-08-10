-- Platform detection shared by options, GUI settings, health checks, and tests.
-- Keep detection in one place so Windows, desktop Linux, WSL, and SSH do not
-- accumulate incompatible one-off checks throughout the configuration.

local M = {}

---@class ConfigPlatformContext
---@field has? fun(feature: string): integer
---@field env? table<string, string|nil>
---@field uname_release? string

---@param context? ConfigPlatformContext
---@return table
function M.detect(context)
    context = context or {}
    local has = context.has or vim.fn.has
    local env = context.env or vim.env
    local release = context.uname_release or (vim.uv.os_uname().release or "")

    local is_windows = has("win32") == 1
    local is_linux = has("linux") == 1
    local is_wsl = is_linux
        and (env.WSL_DISTRO_NAME ~= nil or env.WSL_INTEROP ~= nil or release:lower():find("microsoft", 1, true) ~= nil)
    local is_ssh = env.SSH_CONNECTION ~= nil or env.SSH_CLIENT ~= nil or env.SSH_TTY ~= nil
    local is_wayland = is_linux and env.WAYLAND_DISPLAY ~= nil and env.WAYLAND_DISPLAY ~= ""
    local is_x11 = is_linux and env.DISPLAY ~= nil and env.DISPLAY ~= ""

    local name = "other"
    if is_windows then
        name = "windows"
    elseif is_wsl then
        name = "wsl"
    elseif is_linux then
        name = "linux"
    end

    return {
        name = name,
        is_windows = is_windows,
        is_linux = is_linux,
        is_wsl = is_wsl,
        is_ssh = is_ssh,
        is_remote = is_wsl or is_ssh,
        is_wayland = is_wayland,
        is_x11 = is_x11,
        has_display = is_wayland or is_x11,
    }
end

local current = M.detect()
for key, value in pairs(current) do
    M[key] = value
end

return M
