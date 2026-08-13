-- :checkhealth nvim-config 健康报告。

local health = vim.health
local platform = require("config.platform")
local util = require("config.util")

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
        health.ok("检测到 Neovim 0.12+：" .. tostring(vim.version()))
    else
        health.error("vim.pack 需要 Neovim 0.12+")
    end

    local details = { "platform=" .. platform.name }
    if platform.is_wayland then table.insert(details, "display=wayland") end
    if platform.is_x11 then table.insert(details, "display=x11") end
    if platform.is_ssh then table.insert(details, "ssh=true") end
    health.info(table.concat(details, ", "))

    health.start("系统工具")
    for _, tool in ipairs(util.system_tools) do
        if executable(tool) then
            health.ok(tool .. " 已找到")
        else
            health.error(tool .. " 缺失", { "请运行 scripts/ 下对应的引导脚本。" })
        end
    end

    for label, alternatives in pairs({
        ["压缩包解压器"] = { "unzip", "7z", "tar" },
        ["C 编译器"] = { "cc", "gcc", "clang", "cl" },
        ["Java 运行时"] = { "java" },
        ["Python 运行时"] = { "python", "python3" },
    }) do
        local found = any_executable(alternatives)
        if found then
            health.ok(label .. " 已找到：" .. found)
        else
            health.error(label .. " 缺失", { "请运行 scripts/ 下对应的引导脚本。" })
        end
    end

    if executable("fzf") then
        local result = vim.system({ vim.fn.exepath("fzf"), "--version" }, { text = true }):wait()
        local version_text = result.stdout and result.stdout:match("^(%d+%.%d+%.?%d*)")
        local version = version_text and vim.version.parse(version_text)
        if version and vim.version.ge(version, { 0, 36, 0 }) then
            health.ok("fzf 版本兼容：" .. version_text)
        else
            health.error("fzf-lua 需要 fzf 0.36+", { "请运行 scripts/ 下对应的引导脚本。" })
        end
    end

    local python = any_executable({ "python", "python3" })
    if python then
        local venv_check = vim.system({ vim.fn.exepath(python), "-c", "import venv" }):wait()
        if venv_check.code == 0 then
            health.ok("Python venv 模块已找到")
        else
            health.error("Python venv 模块缺失", { "Ubuntu/Debian：安装 python3-venv" })
        end
    end

    health.start("Mason 管理的 LSP 服务器")
    local installed = {}
    for _, name in ipairs(require("mason-registry").get_installed_package_names()) do
        installed[name] = true
    end
    local mappings = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
    for _, server in ipairs(util.lsp_servers) do
        local package_name = mappings[server]
        if not package_name then
            health.error(server .. " 没有 Mason 映射")
        elseif installed[package_name] then
            health.ok(server .. " 已安装（" .. package_name .. "）")
        else
            health.error(server .. " 缺失（" .. package_name .. "）", { "运行 :MasonToolsInstallSync。" })
        end
    end

    health.start("Mason 管理的格式化器")
    for _, tool in ipairs(util.mason_formatters) do
        if executable(tool) then
            health.ok(tool .. " 已找到")
        else
            health.error(tool .. " 缺失", { "运行 :MasonToolsInstallSync。" })
        end
    end

    if platform.is_linux and platform.has_display and not platform.is_remote then
        if platform.is_wayland and executable("wl-copy") and executable("wl-paste") then
            health.ok("Wayland 剪贴板提供者已找到")
        elseif platform.is_x11 and (executable("xclip") or executable("xsel")) then
            health.ok("X11 剪贴板提供者已找到")
        else
            health.warn("未找到桌面 Linux 剪贴板提供者", {
                "Fedora/Wayland：sudo dnf install wl-clipboard",
                "X11：安装 xclip 或 xsel",
            })
        end
    elseif platform.is_remote then
        if vim.g.clipboard == "osc52" then
            health.ok("WSL/SSH 已强制使用 OSC52 剪贴板")
        else
            health.error("远端会话未使用 OSC52")
        end
        if not vim.tbl_contains(vim.opt.clipboard:get(), "unnamedplus") then
            health.ok("远端无名寄存器保持内部；使用 <leader>y 进行 OSC52 复制")
        else
            health.error("远端 unnamedplus 可能在 OSC52 剪贴板读取时卡住")
        end
    end

    health.start("原生工具链格式化器")
    for _, tool in ipairs({ "gofmt", "rustfmt" }) do
        if executable(tool) then
            health.ok(tool .. " 已找到")
        else
            health.warn(tool .. " 缺失", { "请安装对应的 Go 或 Rust 工具链。" })
        end
    end
end

return M
