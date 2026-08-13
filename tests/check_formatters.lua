-- Formatter configuration (conform options) and per-filetype indent rules.

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- --- Conform options ---------------------------------------------------------

local conform = require("conform")
local clang = conform.get_formatter_config("clang-format")
local shfmt = conform.get_formatter_config("shfmt")
local isort = conform.get_formatter_config("isort")
local prettierd = conform.get_formatter_config("prettierd")
local java = conform.get_formatter_config("google-java-format")

check(vim.tbl_contains(clang.prepend_args or {}, "--style=Google"), "clang-format must use Google Style")
check(vim.tbl_contains(shfmt.args or {}, "4"), "shfmt must use four spaces")
check(vim.tbl_contains(isort.args or {}, "--stdout"), "isort must support the pinned Mason version")
check(type(prettierd.cwd) == "function", "prettierd must resolve the project config directory")
check(prettierd.require_cwd == false, "prettierd must fall back to default formatting without project config")
check(type(java.args) == "table" and java.args[1] == "-", "google-java-format must use Conform's stdin configuration")

local kotlin_buf = vim.api.nvim_create_buf(false, true)
vim.bo[kotlin_buf].filetype = "kotlin"
check(vim.tbl_contains(conform.list_formatters_for_buffer(kotlin_buf), "ktlint"), "Kotlin buffers must route to ktlint")
vim.api.nvim_buf_delete(kotlin_buf, { force = true })

-- --- Indent rules ------------------------------------------------------------

-- Must match the indent_groups table in config/autocmds.lua:
-- [tabstop, shiftwidth, expandtab]
local expected = {
    -- 2 spaces
    lua = { 2, 2, true },
    vim = { 2, 2, true },
    javascript = { 2, 2, true },
    typescript = { 2, 2, true },
    html = { 2, 2, true },
    css = { 2, 2, true },
    json = { 2, 2, true },
    yaml = { 2, 2, true },
    markdown = { 2, 2, true },
    sh = { 2, 2, true },
    toml = { 2, 2, true },
    -- 4 spaces
    python = { 4, 4, true },
    rust = { 4, 4, true },
    c = { 4, 4, true },
    cpp = { 4, 4, true },
    java = { 4, 4, true },
    kotlin = { 4, 4, true },
    -- Tabs
    go = { 4, 4, false },
    make = { 4, 4, false },
}
for ft, exp in pairs(expected) do
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = ft
    vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
    check(vim.bo[buf].tabstop == exp[1], ft .. ": tabstop mismatch")
    check(vim.bo[buf].shiftwidth == exp[2], ft .. ": shiftwidth mismatch")
    check(vim.bo[buf].expandtab == exp[3], ft .. ": expandtab mismatch")
    vim.api.nvim_buf_delete(buf, { force = true })
end

if #failures > 0 then
    io.stderr:write("FORMATTERS_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write(("FORMATTERS_CHECK_OK filetypes=%d\n"):format(vim.tbl_count(expected)))
if not vim.g.config_test_runner then vim.cmd("qa") end
