-- 格式化器配置（conform 选项）与按文件类型的缩进规则。

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- ── conform 选项 ──

local conform = require("conform")
local clang = conform.get_formatter_config("clang-format")
local shfmt = conform.get_formatter_config("shfmt")
local isort = conform.get_formatter_config("isort")
local prettierd = conform.get_formatter_config("prettierd")
local java = conform.get_formatter_config("google-java-format")

check(
    vim.tbl_contains(clang.prepend_args or {}, "--fallback-style=Google"),
    "clang-format 必须以项目配置优先、Google 兜底"
)
check(vim.tbl_contains(shfmt.args or {}, "4"), "shfmt 必须使用 4 空格")
check(vim.tbl_contains(isort.args or {}, "--stdout"), "isort 必须兼容固定的 Mason 版本")
check(type(prettierd.cwd) == "function", "prettierd 必须解析项目配置目录")
check(prettierd.require_cwd == false, "prettierd 无项目配置时必须回退默认格式化")
check(type(java.args) == "table" and java.args[1] == "-", "google-java-format 必须使用 conform 的 stdin 配置")

local kotlin_buf = vim.api.nvim_create_buf(false, true)
vim.bo[kotlin_buf].filetype = "kotlin"
check(
    vim.tbl_contains(conform.list_formatters_for_buffer(kotlin_buf), "ktlint"),
    "Kotlin 缓冲区必须路由到 ktlint"
)
vim.api.nvim_buf_delete(kotlin_buf, { force = true })

-- ── 缩进规则 ──

-- 必须与 config/autocmds.lua 的 indent_groups 表一致：
-- [tabstop, shiftwidth, expandtab]
local expected = {
    -- 2 空格
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
    -- 4 空格
    python = { 4, 4, true },
    rust = { 4, 4, true },
    c = { 4, 4, true },
    cpp = { 4, 4, true },
    java = { 4, 4, true },
    kotlin = { 4, 4, true },
    -- Tab
    go = { 4, 4, false },
    make = { 4, 4, false },
}
for ft, exp in pairs(expected) do
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = ft
    vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
    check(vim.bo[buf].tabstop == exp[1], ft .. "：tabstop 不匹配")
    check(vim.bo[buf].shiftwidth == exp[2], ft .. "：shiftwidth 不匹配")
    check(vim.bo[buf].expandtab == exp[3], ft .. "：expandtab 不匹配")
    vim.api.nvim_buf_delete(buf, { force = true })
end

if #failures > 0 then
    io.stderr:write("FORMATTERS_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write(("FORMATTERS_CHECK_OK filetypes=%d\n"):format(vim.tbl_count(expected)))
if not vim.g.config_test_runner then vim.cmd("qa") end
