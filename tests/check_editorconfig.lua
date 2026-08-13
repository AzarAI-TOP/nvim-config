-- EditorConfig integration: the runtime editorconfig module applies project
-- values on BufRead/BufNewFile; per-filetype indent defaults must yield to
-- them (guard in config/autocmds.lua).

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

local editorconfig = require("config.editorconfig")

-- The runtime wires editorconfig (plugin/editorconfig.lua); this config must
-- NOT add a second application hook (double-apply re-registers BufWritePre
-- autocmds for trim_trailing_whitespace / insert_final_newline).
local runtime_acmds = vim.api.nvim_get_autocmds({ group = "nvim.editorconfig" })
check(#runtime_acmds >= 1, "runtime editorconfig binding must exist")
local ok_group, own_acmds = pcall(vim.api.nvim_get_autocmds, { group = "nvim_config_editorconfig" })
check(not ok_group or #own_acmds == 0, "config must not register its own editorconfig application autocmd")

-- has_indent(): table with indent keys => true; empty/missing/disabled => false.
local scratch = vim.api.nvim_create_buf(false, true)
check(not editorconfig.has_indent(scratch), "fresh buffer must not report indent props")
vim.b[scratch].editorconfig = { indent_style = "space", indent_size = 4 }
check(editorconfig.has_indent(scratch), "applied indent props must be detected")
vim.b[scratch].editorconfig = {}
check(not editorconfig.has_indent(scratch), "empty applied table must not count as indent")
vim.b[scratch].editorconfig = false
check(not editorconfig.has_indent(scratch), "disabled b:editorconfig must not count as indent")
vim.api.nvim_buf_delete(scratch, { force = true })

-- Behavioral: real project tree with .editorconfig (root=true boundary).
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

-- root=true must stop the parent search: the parent's indent_size=2 is ignored.
vim.cmd.edit(py)
local py_buf = vim.api.nvim_get_current_buf()
check(vim.bo.tabstop == 8, "python tabstop must come from project .editorconfig (8)")
check(vim.bo.shiftwidth == 8, "python shiftwidth must come from project .editorconfig (8)")
check(not vim.bo.expandtab, "python buffer must use tabs per indent_style=tab")

-- A late FileType event must not clobber project values (python default = 4).
vim.api.nvim_exec_autocmds("FileType", { buffer = py_buf })
check(vim.bo.shiftwidth == 8, "FileType defaults must yield to project .editorconfig")

vim.cmd.edit(rs)
local rs_buf = vim.api.nvim_get_current_buf()
check(vim.bo.shiftwidth == 3, "rust shiftwidth must follow the [*.rs] section (3)")
check(vim.bo.expandtab, "rust buffer must expand tabs per indent_style=space")

-- Outside any .editorconfig tree the per-filetype defaults stay in effect.
local noroot = vim.fn.tempname()
vim.fn.mkdir(noroot, "p")
local plain_py = vim.fs.joinpath(noroot, "plain.py")
vim.fn.writefile({ "y = 2" }, plain_py)
vim.cmd.edit(plain_py)
local plain_buf = vim.api.nvim_get_current_buf()
check(vim.bo.shiftwidth == 4, "no-project python buffer must keep the 4-space default")
check(vim.bo.expandtab, "no-project python buffer must expand tabs by default")

vim.api.nvim_buf_delete(py_buf, { force = true })
vim.api.nvim_buf_delete(rs_buf, { force = true })
vim.api.nvim_buf_delete(plain_buf, { force = true })
vim.fn.delete(root, "rf")
vim.fn.delete(noroot, "rf")

-- No duplicate application: trim_trailing_whitespace must register exactly
-- one BufWritePre autocmd, and a late FileType re-assert must not add more.
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
check(trim_autocmd_count() == 1, "trim_trailing_whitespace must register exactly one BufWritePre autocmd")
vim.api.nvim_exec_autocmds("FileType", { buffer = trim_buf })
check(trim_autocmd_count() == 1, "FileType re-assert must not duplicate BufWritePre autocmds")
vim.api.nvim_buf_delete(trim_buf, { force = true })
vim.fn.delete(trimroot, "rf")

if #failures > 0 then
    io.stderr:write("EDITORCONFIG_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("EDITORCONFIG_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
