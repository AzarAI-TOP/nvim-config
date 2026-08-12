local failures = {}

local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

local config_root = vim.fn.stdpath("config")
local plugin_init = table.concat(vim.fn.readfile(vim.fs.joinpath(config_root, "lua", "plugins", "init.lua")), "\n")
local mason_source = table.concat(vim.fn.readfile(vim.fs.joinpath(config_root, "lua", "plugins", "mason.lua")), "\n")
local theme_source =
    table.concat(vim.fn.readfile(vim.fs.joinpath(config_root, "lua", "plugins", "tokyonight.lua")), "\n")

check(
    plugin_init:find("NvimConfigInfrastructureReady", 1, true),
    "phase-one loader must emit infrastructure User event"
)
check(
    mason_source:find('pattern = "NvimConfigInfrastructureReady"', 1, true),
    "Mason must initialize on infrastructure User event"
)
check(vim.fn.exists(":Mason") == 2, "Mason commands must be ready after startup")
check(package.loaded["mason"] ~= nil, "Mason should initialize after the infrastructure event")

check(theme_source:find('"ColorSchemePre"', 1, true), "tokyonight must prepare itself on ColorSchemePre")
check(theme_source:find('pattern = "tokyonight*"', 1, true), "tokyonight lazy event must be scoped")
check(vim.g.colors_name == "tokyonight-moon", "the configured theme must still be applied on startup")

local todo_group = vim.api.nvim_get_autocmds({ group = "todo_comments_lazy" })
check(#todo_group > 0, "todo-comments lazy autocmd is missing")

if #failures > 0 then
    io.stderr:write("LIFECYCLE_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("LIFECYCLE_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
