-- Shared utility set for this config: keymap registry, unified keymap binding,
-- editorconfig indent helpers, :PackList row builder, and the LSP / formatter
-- tool lists. All small helper functions live in this one file.

local M = {}

-- ── Keymap registry ──
-- Records every global keymap registered by this config. config.reload deletes
-- all registered mappings first, then keymap modules re-register (and re-record)
-- them; therefore this module must never be cleared during reload.

M.keymaps = {}

---Register a global keymap owned by this config.
---@param mode string|string[]
---@param lhs string
function M.register_keymap(mode, lhs)
    for _, m in ipairs(type(mode) == "table" and mode or { mode }) do
        table.insert(M.keymaps, { mode = m, lhs = lhs })
    end
end

---Delete all registered keymaps (idempotent; mappings already removed by the
---user or a plugin are skipped automatically).
function M.delete_all_keymaps()
    for _, m in ipairs(M.keymaps) do
        pcall(vim.keymap.del, m.mode, m.lhs)
    end
    M.keymaps = {}
end

---Unified keymap entry point: set the mapping, write a description, and record
---it in the registry.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param desc string
---@param opts? table
function M.map(mode, lhs, rhs, desc, opts)
    opts = opts or {}
    -- Ex-command string mappings echo the command line unless silenced; a
    -- ":" in the RHS marks them, so silence by default (callers can pass an
    -- explicit silent = false to override).
    if opts.silent == nil and type(rhs) == "string" and rhs:find(":", 1, true) then
        opts = vim.tbl_extend("force", { silent = true }, opts)
    end
    opts = vim.tbl_extend("force", { desc = desc }, opts)
    vim.keymap.set(mode, lhs, rhs, opts)
    M.register_keymap(mode, lhs)
end

-- ── editorconfig indent helpers ──
-- The runtime's built-in editorconfig integration (plugin/editorconfig.lua)
-- applies project config when a file opens; this config only re-asserts
-- "filetype default indentation yields to project config". It never registers
-- a second apply autocmd — that would duplicate write hooks such as
-- trim_trailing_whitespace.

---Whether the editorconfig attributes applied to a buffer contain indent settings.
---@param bufnr integer
---@return boolean
function M.has_editorconfig_indent(bufnr)
    local applied = vim.b[bufnr].editorconfig
    if type(applied) ~= "table" then return false end
    return applied.indent_style ~= nil or applied.indent_size ~= nil or applied.tab_width ~= nil
end

---Re-apply editorconfig indent after a late FileType event clobbered the
---project values. Only writes buffer options; never re-runs editorconfig.config()
---(that would re-register write hooks).
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

-- ── :PackList row builder ──
-- Lives in util so config/pack.lua only registers user commands, which
-- config.reload can delete and rebuild wholesale on :ConfigReload.

---Strip protocol/host from a plugin source, keep "author/repo"
---(e.g. "https://github.com/folke/noice.nvim" -> "folke/noice.nvim").
---@param src string
---@return string
local function short_src(src)
    local path = src:match("^%a+://[^/]+/(.+)$") or src:match("^git@[^:]+:(.+)$") or src
    return path:gsub("%.git$", "")
end

---Rows sorted by plugin name: "name  author/repo", second column aligned.
---@return string[]
function M.pack_rows()
    local rows = {}
    local width = 0
    for _, plugin in ipairs(vim.pack.get()) do
        local spec = plugin.spec or {}
        local name = spec.name or "?"
        width = math.max(width, #name)
        table.insert(rows, { name = name, src = short_src(spec.src or "") })
    end
    for i, row in ipairs(rows) do
        rows[i] = (string.format("%-" .. width .. "s  %s", row.name, row.src)):gsub("%s+$", "")
    end
    table.sort(rows)
    return rows
end

-- ── Tool lists ──

-- LSP server list; names match the nvim-lspconfig / mason-lspconfig identifiers.
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

-- Portable formatters available from the Mason registry.
-- gofmt and rustfmt deliberately come from the official Go/Rust toolchains
-- (Mason does not publish standalone packages for them).
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

-- mason-tool-installer accepts plain package names.
M.mason_packages = vim.list_extend(vim.list_extend({}, M.lsp_servers), M.mason_formatters)

return M
