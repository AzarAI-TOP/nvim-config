-- editorconfig 集成检查：运行时自带的 editorconfig 模块在 BufRead/BufNewFile
-- 时应用项目值；按文件类型的默认缩进必须让位于项目值
-- （守卫在 config/autocmds.lua）。

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

local util = require("config.util")

-- 运行时自行接线 editorconfig（plugin/editorconfig.lua）；本配置不得
-- 再加第二个应用钩子（重复应用会让 trim_trailing_whitespace /
-- insert_final_newline 的 BufWritePre autocmd 成倍注册）。
local runtime_acmds = vim.api.nvim_get_autocmds({ group = "nvim.editorconfig" })
check(#runtime_acmds >= 1, "运行时的 editorconfig 绑定必须存在")
local ok_group, own_acmds = pcall(vim.api.nvim_get_autocmds, { group = "nvim_config_editorconfig" })
check(not ok_group or #own_acmds == 0, "本配置不得注册自己的 editorconfig 应用 autocmd")

-- has_editorconfig_indent()：含缩进键的表 → true；空表 / 缺失 / 禁用 → false。
local scratch = vim.api.nvim_create_buf(false, true)
check(not util.has_editorconfig_indent(scratch), "全新缓冲区不得报告缩进属性")
vim.b[scratch].editorconfig = { indent_style = "space", indent_size = 4 }
check(util.has_editorconfig_indent(scratch), "已应用的缩进属性必须被检测到")
vim.b[scratch].editorconfig = {}
check(not util.has_editorconfig_indent(scratch), "空应用表不得视为缩进")
vim.b[scratch].editorconfig = false
check(not util.has_editorconfig_indent(scratch), "禁用的 b:editorconfig 不得视为缩进")
vim.api.nvim_buf_delete(scratch, { force = true })

-- 行为验证：带 .editorconfig 的真实项目树（root=true 边界）。
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local project = vim.fs.joinpath(root, "proj")
vim.fn.mkdir(project, "p")
vim.fn.writefile({ "[*]", "indent_size = 2", "indent_style = space" }, vim.fs.joinpath(root, ".editorconfig"))
vim.fn.writefile({
    "root = true",
    "",
    "[*]",
    "indent_style = tab",
    "indent_size = 8",
    "",
    "[*.rs]",
    "indent_style = space",
    "indent_size = 3",
}, vim.fs.joinpath(project, ".editorconfig"))
local py = vim.fs.joinpath(project, "main.py")
vim.fn.writefile({ "x = 1" }, py)
local rs = vim.fs.joinpath(project, "main.rs")
vim.fn.writefile({ "fn main() {}" }, rs)

-- root=true 必须阻断父目录搜索：父级 indent_size=2 被忽略。
vim.cmd.edit(py)
local py_buf = vim.api.nvim_get_current_buf()
check(vim.bo.tabstop == 8, "python 的 tabstop 必须来自项目 .editorconfig（8）")
check(vim.bo.shiftwidth == 8, "python 的 shiftwidth 必须来自项目 .editorconfig（8）")
check(not vim.bo.expandtab, "python 缓冲区必须按 indent_style=tab 使用 Tab")

-- 迟到的 FileType 事件不得覆盖项目值（python 默认 = 4）。
vim.api.nvim_exec_autocmds("FileType", { buffer = py_buf })
check(vim.bo.shiftwidth == 8, "FileType 默认值必须让位于项目 .editorconfig")

vim.cmd.edit(rs)
local rs_buf = vim.api.nvim_get_current_buf()
check(vim.bo.shiftwidth == 3, "rust 的 shiftwidth 必须遵循 [*.rs] 小节（3）")
check(vim.bo.expandtab, "rust 缓冲区必须按 indent_style=space 展开 Tab")

-- 任何 .editorconfig 树之外，按文件类型的默认值保持生效。
local noroot = vim.fn.tempname()
vim.fn.mkdir(noroot, "p")
local plain_py = vim.fs.joinpath(noroot, "plain.py")
vim.fn.writefile({ "y = 2" }, plain_py)
vim.cmd.edit(plain_py)
local plain_buf = vim.api.nvim_get_current_buf()
check(vim.bo.shiftwidth == 4, "无项目的 python 缓冲区必须保持 4 空格默认")
check(vim.bo.expandtab, "无项目的 python 缓冲区必须默认展开 Tab")

vim.api.nvim_buf_delete(py_buf, { force = true })
vim.api.nvim_buf_delete(rs_buf, { force = true })
vim.api.nvim_buf_delete(plain_buf, { force = true })
vim.fn.delete(root, "rf")
vim.fn.delete(noroot, "rf")

-- 无重复应用：trim_trailing_whitespace 必须恰好注册一个 BufWritePre autocmd，
-- 迟到的 FileType 再确认不得新增。
local trimroot = vim.fn.tempname()
vim.fn.mkdir(trimroot, "p")
vim.fn.writefile(
    { "root = true", "[*]", "trim_trailing_whitespace = true", "indent_size = 4" },
    vim.fs.joinpath(trimroot, ".editorconfig")
)
local trimfile = vim.fs.joinpath(trimroot, "t.py")
vim.fn.writefile({ "x = 1" }, trimfile)
vim.cmd.edit(trimfile)
local trim_buf = vim.api.nvim_get_current_buf()
local function trim_autocmd_count()
    return #vim.api.nvim_get_autocmds({ group = "nvim.editorconfig", event = "BufWritePre", buffer = trim_buf })
end
check(trim_autocmd_count() == 1, "trim_trailing_whitespace 必须恰好注册一个 BufWritePre autocmd")
vim.api.nvim_exec_autocmds("FileType", { buffer = trim_buf })
check(trim_autocmd_count() == 1, "FileType 再确认不得重复 BufWritePre autocmd")
vim.api.nvim_buf_delete(trim_buf, { force = true })
vim.fn.delete(trimroot, "rf")

if #failures > 0 then
    io.stderr:write("EDITORCONFIG_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("EDITORCONFIG_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
