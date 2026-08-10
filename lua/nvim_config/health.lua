local health = vim.health
local platform = require("config.platform")
local tools = require("config.tools")

local M = {}

local function executable(name) return vim.fn.executable(name) == 1 end

local function any_executable(names)
    for _, name in ipairs(names) do
        if executable(name) then return name end
    end
end

function M.check()
    health.start("nvim-config")

    if vim.version.ge(vim.version(), { 0, 12, 0 }) then
        health.ok("Neovim 0.12+ detected: " .. tostring(vim.version()))
    else
        health.error("Neovim 0.12+ is required for vim.pack")
    end

    local details = { "platform=" .. platform.name }
    if platform.is_wayland then table.insert(details, "display=wayland") end
    if platform.is_x11 then table.insert(details, "display=x11") end
    if platform.is_ssh then table.insert(details, "ssh=true") end
    health.info(table.concat(details, ", "))

    health.start("system tools")
    for _, tool in ipairs(tools.system_tools) do
        if executable(tool) then
            health.ok(tool .. " found")
        else
            health.error(tool .. " missing", { "Run the matching bootstrap script in scripts/." })
        end
    end

    for label, alternatives in pairs({
        ["archive extractor"] = { "unzip", "7z", "tar" },
        ["C compiler"] = { "cc", "gcc", "clang", "cl" },
        ["Java runtime"] = { "java" },
        ["Python runtime"] = { "python", "python3" },
    }) do
        local found = any_executable(alternatives)
        if found then
            health.ok(label .. " found: " .. found)
        else
            health.error(label .. " missing", { "Run the matching bootstrap script in scripts/." })
        end
    end

    if executable("fzf") then
        local result = vim.system({ vim.fn.exepath("fzf"), "--version" }, { text = true }):wait()
        local version_text = result.stdout and result.stdout:match("^(%d+%.%d+%.?%d*)")
        local version = version_text and vim.version.parse(version_text)
        if version and vim.version.ge(version, { 0, 36, 0 }) then
            health.ok("fzf version is compatible: " .. version_text)
        else
            health.error("fzf 0.36+ is required by fzf-lua", { "Run the matching bootstrap script in scripts/." })
        end
    end

    health.start("Mason-managed formatters")
    for _, tool in ipairs(tools.mason_formatters) do
        if executable(tool) then
            health.ok(tool .. " found")
        else
            health.error(tool .. " missing", { "Run :MasonToolsInstallSync." })
        end
    end

    if platform.is_linux and platform.has_display and not platform.is_remote then
        if platform.is_wayland and executable("wl-copy") and executable("wl-paste") then
            health.ok("Wayland clipboard provider found")
        elseif platform.is_x11 and (executable("xclip") or executable("xsel")) then
            health.ok("X11 clipboard provider found")
        else
            health.warn("No desktop Linux clipboard provider found", {
                "Fedora/Wayland: sudo dnf install wl-clipboard",
                "X11: install xclip or xsel",
            })
        end
    elseif platform.is_remote then
        if vim.g.clipboard == "osc52" then
            health.ok("OSC52 clipboard forced for WSL/SSH")
        else
            health.error("Remote session is not using OSC52")
        end
    end

    health.start("native toolchain formatters")
    for _, tool in ipairs({ "gofmt", "rustfmt" }) do
        if executable(tool) then
            health.ok(tool .. " found")
        else
            health.warn(tool .. " missing", { "Install the corresponding Go or Rust toolchain." })
        end
    end
end

return M
