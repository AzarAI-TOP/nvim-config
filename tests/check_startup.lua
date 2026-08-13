-- 启动冒烟检查：键位、shell、LSP 配置与夹具。

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- ── 键位 ──

-- bento 必须拥有 <leader>bb；分号不得被重映射。
check(vim.fn.maparg(";", "n") == "", "分号不得被重映射")
check(vim.fn.maparg("<leader>bb", "n") ~= "", "<leader>bb（缓冲区选择器）必须有映射")

-- <leader>lf 必须使用带 async 与通知的 conform 回调。
local format_mapping = vim.fn.maparg("<leader>lf", "n", false, true)
check(type(format_mapping.callback) == "function", "<leader>lf 必须使用 Lua 回调")
local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level) table.insert(notifications, { message = message, level = level }) end
if type(format_mapping.callback) == "function" then
    local original_conform = package.loaded["conform"]
    package.loaded["conform"] = {
        format = function(options, callback)
            check(options.async == true, "格式化必须是异步的")
            callback(nil, true)
        end,
    }
    format_mapping.callback()
    check(#notifications == 1 and notifications[1].message == "已格式化", "缺少成功通知")

    notifications = {}
    package.loaded["conform"].format = function(_, callback) callback("formatter failed", false) end
    format_mapping.callback()
    check(
        #notifications == 1 and notifications[1].level == vim.log.levels.ERROR,
        "格式化错误必须产生错误通知"
    )
    package.loaded["conform"] = original_conform
end
vim.notify = original_notify

-- LSP 键位。
check(vim.fn.maparg("<C-Space>", "i") ~= "", "<C-Space> 必须映射到补全")
check(vim.fn.maparg("<leader>ld", "n") ~= "", "<leader>ld 必须有映射")
check(vim.fn.maparg("<leader>lf", "n") ~= "", "<leader>lf 必须有映射")
check(vim.fn.maparg("]d", "n") ~= "", "]d 诊断导航必须有映射")
check(vim.fn.maparg("[d", "n") ~= "", "[d 诊断导航必须有映射")

-- 包管理键位。
check(vim.fn.maparg("<leader>pm", "n") == ":Mason<CR>", "<leader>pm 必须打开 Mason")
check(vim.fn.maparg("<leader>pu", "n") == ":PackUpdate<CR>", "<leader>pu 必须更新插件")
check(vim.fn.maparg("<leader>pU", "n") == ":MasonToolsUpdate<CR>", "<leader>pU 必须更新 Mason 工具")
check(vim.fn.maparg("<leader>pp", "n") == ":PackList<CR>", "<leader>pp 必须列出插件")
check(vim.fn.maparg("<leader>pc", "n") == "", "<leader>pc 必须已移除（由 pm 取代）")
check(vim.fn.maparg("<leader>pi", "n") == ":MasonToolsInstallSync<CR>", "<leader>pi 必须安装 Mason 工具")

-- ── Shell（Windows） ──

if vim.fn.has("win32") == 1 then
    local output = vim.fn.system("echo PLATFORM_SHELL_OK")
    check(vim.v.shell_error == 0 and output:find("PLATFORM_SHELL_OK", 1, true), "shell 必须能运行命令")
    check(vim.o.shell == (vim.env.COMSPEC or "cmd.exe"), "Windows 上 shell 必须固定为 cmd.exe")
end

-- ── LSP 配置 ──

local servers = require("config.util").lsp_servers
local ok, err = pcall(function()
    for _, server in ipairs(servers) do
        local config = vim.lsp.config[server]
        assert(config, server .. "：配置缺失")
        local cmd_type = type(config.cmd)
        assert(cmd_type == "function" or (cmd_type == "table" and config.cmd[1]), server .. "：cmd 缺失")
        assert(type(config.filetypes) == "table" and config.filetypes[1], server .. "：filetypes 缺失")
    end
end)
check(ok, "LSP 配置错误：" .. tostring(err))

-- ── 夹具 ──

local fixtures = {
    bashls = { file = "sample.sh", filetype = "sh" },
    clangd = { file = "sample.cpp", filetype = "cpp" },
    cssls = { file = "sample.css", filetype = "css" },
    gopls = { file = "sample.go", filetype = "go" },
    html = { file = "sample.html", filetype = "html" },
    jsonls = { file = "sample.json", filetype = "json" },
    kotlin_lsp = { file = "sample.kt", filetype = "kotlin" },
    lua_ls = { file = "sample.lua", filetype = "lua" },
    pyright = { file = "sample.py", filetype = "python" },
    rust_analyzer = { file = "sample.rs", filetype = "rust" },
    ts_ls = { file = "sample.ts", filetype = "typescript" },
    yamlls = { file = "sample.yaml", filetype = "yaml" },
}
local root = vim.fs.joinpath(vim.fn.stdpath("config"), "tests", "fixtures")
for server, fixture in pairs(fixtures) do
    check(vim.fn.filereadable(vim.fs.joinpath(root, fixture.file)) == 1, server .. " 夹具缺失：" .. fixture.file)
    local config = vim.lsp.config[server]
    check(
        config and vim.tbl_contains(config.filetypes or {}, fixture.filetype),
        server .. " 夹具文件类型未映射：" .. fixture.filetype
    )
end

-- ── 懒加载机制 ──

-- tokyonight 的 ColorSchemePre 钩子 once=true，启动时必然已触发（分组为空）；
-- todo-comments 仍须延迟到第一个文件。
check(vim.g.colors_name == "tokyonight-moon", "启动时必须应用配置的主题")
check(
    #vim.api.nvim_get_autocmds({ group = "tokyonight_lazy_setup" }) == 0,
    "tokyonight 的 ColorSchemePre 钩子启动时必须已触发一次"
)
check(#vim.api.nvim_get_autocmds({ group = "todo_comments_lazy" }) > 0, "todo-comments 懒加载 autocmd 缺失")

if #failures > 0 then
    io.stderr:write("STARTUP_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write(("STARTUP_CHECK_OK servers=%d fixtures=%d\n"):format(#servers, vim.tbl_count(fixtures)))
if not vim.g.config_test_runner then vim.cmd("qa") end
