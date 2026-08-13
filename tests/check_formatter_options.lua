local failures = {}

local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

local conform = require("conform")

local clang = conform.get_formatter_config("clang-format")
local shfmt = conform.get_formatter_config("shfmt")
local isort = conform.get_formatter_config("isort")
local prettierd = conform.get_formatter_config("prettierd")
local java = conform.get_formatter_config("google-java-format")

check(vim.tbl_contains(clang.prepend_args or {}, "--style=Google"), "clang-format must use Google Style")
check(vim.tbl_contains(shfmt.args or {}, "4"), "shfmt must use four spaces")
check(vim.tbl_contains(isort.args or {}, "--stdout"), "isort must support the pinned Mason version")
check(not vim.tbl_contains(isort.args or {}, "--line-ending"), "isort must avoid the incompatible line-ending argument")
check(type(prettierd.cwd) == "function", "prettierd must resolve the project config directory")
check(prettierd.require_cwd == false, "prettierd must fall back to default formatting when project config is absent")
check(type(java.args) == "table" and java.args[1] == "-", "google-java-format must use Conform's stdin configuration")

-- Behavioral filetype routing: a Kotlin buffer must resolve to ktlint.
local kotlin_buf = vim.api.nvim_create_buf(false, true)
vim.bo[kotlin_buf].filetype = "kotlin"
local kotlin_formatters = conform.list_formatters_for_buffer(kotlin_buf)
check(
    vim.tbl_contains(kotlin_formatters, "ktlint"),
    "Kotlin buffers must route to ktlint (got: " .. table.concat(kotlin_formatters or {}, ", ") .. ")"
)
vim.api.nvim_buf_delete(kotlin_buf, { force = true })

if #failures > 0 then
    io.stderr:write("FORMATTER_OPTIONS_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("FORMATTER_OPTIONS_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
