-- 本配置共用的工具集合：按键登记表、统一按键绑定、editorconfig 缩进辅助、
-- 以及 LSP/格式化器/系统工具清单。所有小工具函数集中在这一个文件里。

local M = {}

-- ── 按键登记表 ──
-- 记录本配置注册的全局按键。config.reload 会先删除全部已登记映射，
-- 再由按键模块重新注册（并重新登记）；因此本模块在 reload 时不得被清空。

M.keymaps = {}

---登记一个本配置拥有的全局按键。
---@param mode string|string[]
---@param lhs string
function M.register_keymap(mode, lhs)
    for _, m in ipairs(type(mode) == "table" and mode or { mode }) do
        table.insert(M.keymaps, { mode = m, lhs = lhs })
    end
end

---删除全部已登记按键（幂等；被用户或插件手动删除的按键自动跳过）。
function M.delete_all_keymaps()
    for _, m in ipairs(M.keymaps) do
        pcall(vim.keymap.del, m.mode, m.lhs)
    end
    M.keymaps = {}
end

---统一的按键绑定入口：设置映射、写入描述、登记到登记表。
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param desc string
---@param opts? table
function M.map(mode, lhs, rhs, desc, opts)
    opts = vim.tbl_extend("force", { desc = desc }, opts or {})
    vim.keymap.set(mode, lhs, rhs, opts)
    M.register_keymap(mode, lhs)
end

-- ── editorconfig 缩进辅助 ──
-- 运行时自带的 editorconfig 集成（plugin/editorconfig.lua）负责在文件打开时
-- 应用项目配置；本配置只做"文件类型默认缩进让位于项目配置"的再确认，
-- 绝不重复注册应用 autocmd，否则 trim_trailing_whitespace 等写钩子会被重复添加。

---缓冲区已应用的 editorconfig 属性里是否含缩进设置。
---@param bufnr integer
---@return boolean
function M.has_editorconfig_indent(bufnr)
    local applied = vim.b[bufnr].editorconfig
    if type(applied) ~= "table" then return false end
    return applied.indent_style ~= nil or applied.indent_size ~= nil or applied.tab_width ~= nil
end

---在迟到的 FileType 事件覆盖项目缩进值之后，重新应用 editorconfig 缩进。
---只写缓冲区选项，不重新执行 editorconfig.config()（那会重复注册写钩子）。
---@param bufnr integer
function M.reapply_editorconfig_indent(bufnr)
    local applied = vim.b[bufnr].editorconfig
    if type(applied) ~= "table" then return end
    if applied.indent_style ~= nil then
        vim.bo[bufnr].expandtab = applied.indent_style == "space"
        if applied.indent_style == "tab" and applied.indent_size == nil then
            vim.bo[bufnr].shiftwidth = 0
            vim.bo[bufnr].softtabstop = 0
        end
    end
    if applied.indent_size ~= nil then
        if applied.indent_size == "tab" then
            vim.bo[bufnr].shiftwidth = 0
            vim.bo[bufnr].softtabstop = 0
        else
            local n = tonumber(applied.indent_size)
            vim.bo[bufnr].shiftwidth = n
            vim.bo[bufnr].softtabstop = -1
            if applied.tab_width == nil then vim.bo[bufnr].tabstop = n end
        end
    end
    if applied.tab_width ~= nil then vim.bo[bufnr].tabstop = tonumber(applied.tab_width) end
end

-- ── 工具清单 ──

-- LSP 服务器列表，名称与 nvim-lspconfig / mason-lspconfig 的标识一致。
M.lsp_servers = {
    "gopls",
    "clangd",
    "rust_analyzer",
    "ts_ls",
    "html",
    "cssls",
    "jsonls",
    "pyright",
    "lua_ls",
    "bashls",
    "yamlls",
    "kotlin_lsp",
}

-- Mason 注册表提供的便携格式化器。
-- gofmt 与 rustfmt 刻意来自 Go/Rust 官方工具链（Mason 不发布独立包）。
M.mason_formatters = {
    "black",
    "clang-format",
    "goimports",
    "isort",
    "prettierd",
    "shfmt",
    "stylua",
    "taplo",
    "google-java-format",
    "ktlint",
}

-- mason-tool-installer 接受普通包名。
M.mason_packages = vim.list_extend(vim.list_extend({}, M.lsp_servers), M.mason_formatters)

-- 系统层工具（Mason 之外）：Linux 引导脚本安装通用工具，
-- 语言专属格式化器随各自工具链安装。
M.system_tools = {
    "git",
    "curl",
    "fzf",
    "rg",
    "node",
    "npm",
}

return M
