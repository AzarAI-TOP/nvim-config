local failures = {}

local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

check(type(_G.MiniSnippets) == "table", "mini.snippets must be initialized")
check(type(MiniSnippets.config.snippets) == "table" and #MiniSnippets.config.snippets > 0, "snippet loader is missing")

local config_root = vim.fn.stdpath("config")
for _, lang in ipairs({ "c", "cpp", "python" }) do
    local path = vim.fs.joinpath(config_root, "snippets", lang .. ".json")
    local snippets = MiniSnippets.read_file(path, { cache = false, silent = true })
    check(type(snippets) == "table" and #snippets > 0, lang .. " snippets must parse")
end

local c_snippets = MiniSnippets.read_file(vim.fs.joinpath(config_root, "snippets", "c.json"), { cache = false })
local printf
for _, snippet in ipairs(c_snippets or {}) do
    if snippet.prefix == "printf" then printf = snippet end
end
check(printf ~= nil, "C printf snippet is missing")
check(printf and printf.body:find("\\n", 1, true), "printf must contain a literal \\n escape")

local markdown = vim.api.nvim_create_buf(false, true)
vim.bo[markdown].filetype = "markdown"
-- Use the config's own FileType group only; the isolated test data intentionally
-- has no Tree-sitter parsers for Neovim's stock Markdown ftplugin.
vim.api.nvim_exec_autocmds("FileType", { buffer = markdown, group = "disable_markdown_snippets" })
check(vim.b[markdown].minisnippets_disable == true, "snippets must be disabled in Markdown")
vim.api.nvim_buf_delete(markdown, { force = true })

local lsp_source = table.concat(vim.fn.readfile(vim.fs.joinpath(config_root, "lua", "config", "lsp.lua")), "\n")
check(
    lsp_source:find("vim.lsp.completion.enable(true, client.id, args.buf", 1, true),
    "completion must be enabled per attached client"
)
check(lsp_source:find('filetype == "markdown"', 1, true), "LSP completion must explicitly exclude Markdown")

if #failures > 0 then
    io.stderr:write("COMPLETION_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("COMPLETION_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
