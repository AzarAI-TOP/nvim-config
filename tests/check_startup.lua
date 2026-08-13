-- Startup smoke checks: key mappings, shell, LSP config, and fixtures.

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- --- Keymaps ---------------------------------------------------------------

-- bento must own <leader>bb; semicolon must not be remapped.
check(vim.fn.maparg(";", "n") == "", "semicolon must not be remapped")
check(vim.fn.maparg("<leader>bb", "n") ~= "", "<leader>bb (buffer picker) must be mapped")

-- <leader>lf must use the conform callback with async + notifications.
local format_mapping = vim.fn.maparg("<leader>lf", "n", false, true)
check(type(format_mapping.callback) == "function", "<leader>lf must use a Lua callback")
local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level) table.insert(notifications, { message = message, level = level }) end
if type(format_mapping.callback) == "function" then
    local original_conform = package.loaded["conform"]
    package.loaded["conform"] = {
        format = function(options, callback)
            check(options.async == true, "formatting must be asynchronous")
            callback(nil, true)
        end,
    }
    format_mapping.callback()
    check(#notifications == 1 and notifications[1].message == "已格式化", "success notification missing")

    notifications = {}
    package.loaded["conform"].format = function(_, callback) callback("formatter failed", false) end
    format_mapping.callback()
    check(
        #notifications == 1 and notifications[1].level == vim.log.levels.ERROR,
        "format errors must produce an error notification"
    )
    package.loaded["conform"] = original_conform
end
vim.notify = original_notify

-- LSP keymaps.
check(vim.fn.maparg("<C-Space>", "i") ~= "", "<C-Space> must be mapped for completion")
check(vim.fn.maparg("<leader>ld", "n") ~= "", "<leader>ld must be mapped")
check(vim.fn.maparg("<leader>lf", "n") ~= "", "<leader>lf must be mapped")
check(vim.fn.maparg("]d", "n") ~= "", "]d diagnostic navigation must be mapped")
check(vim.fn.maparg("[d", "n") ~= "", "[d diagnostic navigation must be mapped")

-- --- Shell (Windows) -------------------------------------------------------

if vim.fn.has("win32") == 1 then
    local output = vim.fn.system("echo PLATFORM_SHELL_OK")
    check(vim.v.shell_error == 0 and output:find("PLATFORM_SHELL_OK", 1, true), "shell must run commands")
    check(vim.o.shell == (vim.env.COMSPEC or "cmd.exe"), "shell must be pinned to cmd.exe on Windows")
end

-- --- LSP configs ------------------------------------------------------------

local servers = require("config.tools").lsp_servers
local ok, err = pcall(function()
    for _, server in ipairs(servers) do
        local config = vim.lsp.config[server]
        assert(config, server .. ": config is missing")
        local cmd_type = type(config.cmd)
        assert(cmd_type == "function" or (cmd_type == "table" and config.cmd[1]), server .. ": cmd is missing")
        assert(type(config.filetypes) == "table" and config.filetypes[1], server .. ": filetypes are missing")
    end
end)
check(ok, "LSP config error: " .. tostring(err))

-- --- Fixtures ---------------------------------------------------------------

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
    check(vim.fn.filereadable(vim.fs.joinpath(root, fixture.file)) == 1, server .. " fixture missing: " .. fixture.file)
    local config = vim.lsp.config[server]
    check(
        config and vim.tbl_contains(config.filetypes or {}, fixture.filetype),
        server .. " fixture filetype is not mapped: " .. fixture.filetype
    )
end

-- --- Lazy mechanisms ---------------------------------------------------------

-- tokyonight's ColorSchemePre hook is once=true and must have fired during
-- startup (group empty); todo-comments must still be deferred to first file.
check(vim.g.colors_name == "tokyonight-moon", "the configured theme must be applied at startup")
check(
    #vim.api.nvim_get_autocmds({ group = "tokyonight_lazy_setup" }) == 0,
    "tokyonight ColorSchemePre hook must have fired once during startup"
)
check(#vim.api.nvim_get_autocmds({ group = "todo_comments_lazy" }) > 0, "todo-comments lazy autocmd is missing")

if #failures > 0 then
    io.stderr:write("STARTUP_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write(("STARTUP_CHECK_OK servers=%d fixtures=%d\n"):format(#servers, vim.tbl_count(fixtures)))
if not vim.g.config_test_runner then vim.cmd("qa") end
