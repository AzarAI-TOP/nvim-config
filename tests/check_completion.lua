-- 补全与片段的行为检查。
-- 原生 LSP 补全模块（config/lsp.lua）用模拟客户端与 spy 调用验证，
-- 不搜索源码文本。

local failures = {}

local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

check(type(_G.MiniSnippets) == "table", "mini.snippets 必须已初始化")
check(type(MiniSnippets.config.snippets) == "table" and #MiniSnippets.config.snippets > 0, "片段加载器缺失")

local config_root = vim.fn.stdpath("config")
for _, lang in ipairs({ "c", "cpp", "python" }) do
    local path = vim.fs.joinpath(config_root, "snippets", lang .. ".json")
    local snippets = MiniSnippets.read_file(path, { cache = false, silent = true })
    check(type(snippets) == "table" and #snippets > 0, lang .. " 片段必须能解析")
end

local c_snippets = MiniSnippets.read_file(vim.fs.joinpath(config_root, "snippets", "c.json"), { cache = false })
local printf
for _, snippet in ipairs(c_snippets or {}) do
    if snippet.prefix == "printf" then printf = snippet end
end
check(printf ~= nil, "缺少 C printf 片段")
check(printf and printf.body:find("\\n", 1, true), "printf 必须包含字面量 \\n 转义")

local markdown = vim.api.nvim_create_buf(false, true)
vim.bo[markdown].filetype = "markdown"
check(vim.b[markdown].minisnippets_disable ~= true, "Markdown 中片段必须保持可用")
local has_disable_group = pcall(vim.api.nvim_get_autocmds, { group = "disable_markdown_snippets" })
check(not has_disable_group, "Markdown 不得存在禁用片段的 autocmd")
vim.api.nvim_buf_delete(markdown, { force = true })

-- ── LSP 补全生命周期行为检查 ──
local completion = require("config.lsp")

local code_buf = vim.api.nvim_create_buf(false, true)
vim.bo[code_buf].filetype = "lua"
local md_buf = vim.api.nvim_create_buf(false, true)
vim.bo[md_buf].filetype = "markdown"

-- 监视 vim.lsp.completion.enable 与 vim.lsp.completion.get。
local enable_calls = {}
local get_calls = 0
local orig_enable = vim.lsp.completion.enable
local orig_get = vim.lsp.completion.get
local orig_get_client = vim.lsp.get_client_by_id

-- 行为主体在 pcall 中运行：无论断言失败还是运行时错误，
-- 下方都会恢复被模拟的 vim.lsp 状态与临时缓冲区，
-- headless nvim 进程不会挂在模拟状态上。
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

    -- 代码缓冲区上的有能力的客户端必须恰好启用一次补全，且参数与生产代码一致。
    vim.lsp.get_client_by_id = function(id) return capable end
    enable_calls = {}
    completion.enable_for_client({ buf = code_buf, data = { client_id = 101 } })
    check(#enable_calls == 1, "有能力的代码客户端必须恰好启用一次补全")
    check(supported_method == "textDocument/completion", "能力检查必须查询 textDocument/completion")
    check(supported_buf == code_buf, "能力检查必须使用附着的缓冲区")
    if #enable_calls == 1 then
        local call = enable_calls[1]
        check(call[1] == true, "必须启用补全")
        check(call[2] == 101, "必须为附着的客户端 id 启用补全")
        check(call[3] == code_buf, "必须为附着的缓冲区启用补全")
        check(type(call[4]) == "table" and call[4].autotrigger == true, "补全必须使用 autotrigger = true")
    end

    -- 无能力的客户端不得启用补全。
    vim.lsp.get_client_by_id = function(id) return incapable end
    enable_calls = {}
    completion.enable_for_client({ buf = code_buf, data = { client_id = 102 } })
    check(#enable_calls == 0, "无能力的客户端不得启用补全")

    -- Markdown 永不启用补全，即使客户端有能力。
    vim.lsp.get_client_by_id = function(id) return capable end
    enable_calls = {}
    completion.enable_for_client({ buf = md_buf, data = { client_id = 101 } })
    check(#enable_calls == 0, "Markdown 永不启用 LSP 补全")

    -- 缺失的客户端不得启用补全。
    vim.lsp.get_client_by_id = function() return nil end
    enable_calls = {}
    completion.enable_for_client({ buf = code_buf, data = { client_id = 999 } })
    check(#enable_calls == 0, "缺失的客户端不得启用补全")

    -- LspAttach autocmd 必须已注册且绑定生产回调。
    local ok_lsp, lsp_autocmds = pcall(vim.api.nvim_get_autocmds, { group = "lsp_completion" })
    check(ok_lsp and type(lsp_autocmds) == "table" and #lsp_autocmds == 1, "必须恰好注册一个 LspAttach autocmd")
    if ok_lsp and type(lsp_autocmds) == "table" and #lsp_autocmds == 1 then
        check(lsp_autocmds[1].event == "LspAttach", "补全 autocmd 必须监听 LspAttach")
        check(type(lsp_autocmds[1].callback) == "function", "补全 autocmd 必须有回调")
    end

    -- <C-Space> 在代码缓冲区请求补全，在 Markdown 中保持静默。
    local cspace = vim.fn.maparg("<C-Space>", "i", false, true)
    check(type(cspace.callback) == "function", "<C-Space> 必须在插入模式有映射")
    check(cspace.callback == completion.trigger, "<C-Space> 必须调用生产 trigger")

    vim.api.nvim_set_current_buf(code_buf)
    vim.bo[code_buf].filetype = "lua"
    get_calls = 0
    completion.trigger()
    check(get_calls == 1, "<C-Space> 必须在代码缓冲区请求补全")

    vim.api.nvim_set_current_buf(md_buf)
    vim.bo[md_buf].filetype = "markdown"
    get_calls = 0
    completion.trigger()
    check(get_calls == 0, "<C-Space> 必须在 Markdown 中保持静默")
end)

-- 无条件恢复生产函数并删除临时缓冲区。
vim.lsp.completion.enable = orig_enable
vim.lsp.completion.get = orig_get
vim.lsp.get_client_by_id = orig_get_client
vim.api.nvim_buf_delete(code_buf, { force = true })
vim.api.nvim_buf_delete(md_buf, { force = true })

-- 行为主体内的运行时错误与断言失败同等对待：记录下来，
-- 走下方失败路径 cquit 退出，headless nvim 不会挂在模拟状态上。
if not ok_body then table.insert(failures, "行为主体报错: " .. tostring(body_err)) end

if #failures > 0 then
    io.stderr:write("COMPLETION_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("COMPLETION_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
