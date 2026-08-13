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
check(vim.b[markdown].minisnippets_disable ~= true, "snippets must remain available in Markdown")
local has_disable_group = pcall(vim.api.nvim_get_autocmds, { group = "disable_markdown_snippets" })
check(not has_disable_group, "Markdown must not have a snippet-disabling autocmd")
vim.api.nvim_buf_delete(markdown, { force = true })

-- ---------------------------------------------------------------------------
-- Behavioral LSP completion lifecycle tests.
-- The production module lua/config/lsp_completion.lua is invoked with mocked
-- clients and spies; no source text is searched.
-- ---------------------------------------------------------------------------
local completion = require("config.lsp_completion")

local code_buf = vim.api.nvim_create_buf(false, true)
vim.bo[code_buf].filetype = "lua"
local md_buf = vim.api.nvim_create_buf(false, true)
vim.bo[md_buf].filetype = "markdown"

-- Spy on vim.lsp.completion.enable and vim.lsp.completion.get.
local enable_calls = {}
local get_calls = 0
local orig_enable = vim.lsp.completion.enable
local orig_get = vim.lsp.completion.get
local orig_get_client = vim.lsp.get_client_by_id

-- The behavioral body runs under pcall so the mocked vim.lsp state and scratch
-- buffers are restored below on every path -- assertion failure or runtime
-- error alike -- and the headless nvim process always terminates instead of
-- hanging on mocked state.
local ok_body, body_err = pcall(function()
    vim.lsp.completion.enable = function(...) table.insert(enable_calls, { ... }) end
    vim.lsp.completion.get = function() get_calls = get_calls + 1 end

    local supported_method, supported_buf
    local capable = {
        id = 101,
        supports_method = function(_, method, bufnr)
            supported_method, supported_buf = method, bufnr
            return method == "textDocument/completion"
        end,
    }
    local incapable = {
        id = 102,
        supports_method = function() return false end,
    }

    -- A capable client on a code buffer must enable completion exactly once with
    -- the exact production arguments.
    vim.lsp.get_client_by_id = function(id) return capable end
    enable_calls = {}
    completion.enable_for_client({ buf = code_buf, data = { client_id = 101 } })
    check(#enable_calls == 1, "capable code client must enable completion exactly once")
    check(supported_method == "textDocument/completion", "capability check must query textDocument/completion")
    check(supported_buf == code_buf, "capability check must use the attached buffer")
    if #enable_calls == 1 then
        local call = enable_calls[1]
        check(call[1] == true, "completion must be enabled")
        check(call[2] == 101, "completion must be enabled for the attached client id")
        check(call[3] == code_buf, "completion must be enabled for the attached buffer")
        check(type(call[4]) == "table" and call[4].autotrigger == true, "completion must use autotrigger = true")
    end

    -- An incapable client must never enable completion.
    vim.lsp.get_client_by_id = function(id) return incapable end
    enable_calls = {}
    completion.enable_for_client({ buf = code_buf, data = { client_id = 102 } })
    check(#enable_calls == 0, "incapable client must not enable completion")

    -- Markdown must never enable completion, even for a capable client.
    vim.lsp.get_client_by_id = function(id) return capable end
    enable_calls = {}
    completion.enable_for_client({ buf = md_buf, data = { client_id = 101 } })
    check(#enable_calls == 0, "Markdown must never enable LSP completion")

    -- A missing client must not enable completion.
    vim.lsp.get_client_by_id = function() return nil end
    enable_calls = {}
    completion.enable_for_client({ buf = code_buf, data = { client_id = 999 } })
    check(#enable_calls == 0, "a missing client must not enable completion")

    -- The LspAttach autocmd must actually be registered with the production callback.
    local ok_lsp, lsp_autocmds = pcall(vim.api.nvim_get_autocmds, { group = "lsp_completion" })
    check(
        ok_lsp and type(lsp_autocmds) == "table" and #lsp_autocmds == 1,
        "exactly one LspAttach autocmd must be registered"
    )
    if ok_lsp and type(lsp_autocmds) == "table" and #lsp_autocmds == 1 then
        check(lsp_autocmds[1].event == "LspAttach", "completion autocmd must listen to LspAttach")
        check(type(lsp_autocmds[1].callback) == "function", "completion autocmd must have a callback")
    end

    -- <C-Space> must request completion in code buffers and stay inert in Markdown.
    local cspace = vim.fn.maparg("<C-Space>", "i", false, true)
    check(type(cspace.callback) == "function", "<C-Space> must be mapped in insert mode")
    check(cspace.callback == completion.trigger, "<C-Space> must invoke the production trigger")

    vim.api.nvim_set_current_buf(code_buf)
    vim.bo[code_buf].filetype = "lua"
    get_calls = 0
    completion.trigger()
    check(get_calls == 1, "<C-Space> must request completion in a code buffer")

    vim.api.nvim_set_current_buf(md_buf)
    vim.bo[md_buf].filetype = "markdown"
    get_calls = 0
    completion.trigger()
    check(get_calls == 0, "<C-Space> must be inert in Markdown")
end)

-- Restore production functions and delete scratch buffers unconditionally.
vim.lsp.completion.enable = orig_enable
vim.lsp.completion.get = orig_get
vim.lsp.get_client_by_id = orig_get_client
vim.api.nvim_buf_delete(code_buf, { force = true })
vim.api.nvim_buf_delete(md_buf, { force = true })

-- A runtime error inside the behavioral body is a failure like any assertion:
-- record it and let the failure path below exit via cquit, so the headless
-- nvim never hangs on mocked state.
if not ok_body then table.insert(failures, "behavioral body errored: " .. tostring(body_err)) end

if #failures > 0 then
    io.stderr:write("COMPLETION_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("COMPLETION_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
