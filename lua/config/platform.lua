-- Platform detection: shared by Windows / desktop Linux / WSL / SSH and used
-- by options, GUI settings, health checks, and tests.
-- Detection lives in one place so one-off judgments don't drift apart.

local M = {}

local function nonempty(value) return value ~= nil and value ~= "" end

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
        and (
            nonempty(env.WSL_DISTRO_NAME)
            or nonempty(env.WSL_INTEROP)
            or release:lower():find("microsoft", 1, true) ~= nil
        )
    local is_ssh = nonempty(env.SSH_CONNECTION) or nonempty(env.SSH_CLIENT) or nonempty(env.SSH_TTY)
    local is_wayland = is_linux and nonempty(env.WAYLAND_DISPLAY)
    local is_x11 = is_linux and nonempty(env.DISPLAY)

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

-- Flatten the current environment's detection result onto module fields.
local current = M.detect()
for key, value in pairs(current) do
    M[key] = value
end

return M
