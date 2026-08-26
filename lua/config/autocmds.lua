-- Autocommands: yank/put highlight, cursor-position restore, per-filetype indentation.

local util = require("config.util")

-- ── Yank / paste highlight ──
-- Prefer vim.hl.hl_op (Neovim >= 0.13), fall back to vim.hl.on_yank (0.12.x).
if vim.hl.hl_op then
    vim.api.nvim_create_autocmd({ "TextYankPost", "TextPutPost" }, {
        group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
        callback = function() vim.hl.hl_op({ higroup = "IncSearch", timeout = 150 }) end,
    })
else
    vim.api.nvim_create_autocmd("TextYankPost", {
        group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
        callback = function() vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 }) end,
    })
end

-- ── Restore last cursor position when opening a file ──
vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("last_position", { clear = true }),
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
    end,
})

-- ── Per-filetype indentation ──
-- The global default lives in options.lua: 4 spaces, expandtab; this block only
-- overrides non-default filetypes, everything else keeps the global default.
--
-- Project .editorconfig wins: the runtime applies it when a file opens
-- (plugin/editorconfig.lua); the FileType callbacks below re-assert the project
-- values after a late FileType event lets ftplugin/indent handlers clobber them.

local indent_augroup = vim.api.nvim_create_augroup("indent_settings", { clear = true })

-- Indent group format: [tabstop, shiftwidth, expandtab, filetype list]
local indent_groups = {
    -- 2 spaces — web / scripting / markup / declarative languages; java sits
    -- here because google-java-format mandates 2-space Google Java Style.
    {
        2,
        2,
        true,
        {
            "vim",
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "html",
            "css",
            "scss",
            "less",
            "sass",
            "json",
            "jsonc",
            "yaml",
            "ruby",
            "eruby",
            "fish",
            "markdown",
            "elixir",
            "eelixir",
            "heex",
            "haskell",
            "lhaskell",
            "ocaml",
            "reason",
            "scala",
            "dart",
            "cmake",
            "graphql",
            "svelte",
            "vue",
            "terraform",
            "hcl",
            "toml",
            "nix",
            "rescript",
            "gleam",
            "java",
        },
    },

    -- 4 spaces — systems / traditional languages; lua follows the repo's
    -- .stylua.toml (Spaces/4), sh/bash follow shfmt's pinned -i 4
    -- (plugins/conform.lua).
    {
        4,
        4,
        true,
        {
            "lua",
            "sh",
            "bash",
            "python",
            "rust",
            "kotlin",
            "swift",
            "fsharp",
            "zig",
            "ada",
            "perl",
            "prolog",
            "solidity",
            "pascal",
        },
    },

    -- Tab indentation — toolchains that mandate tabs
    { 4, 4, false, {
        "go",
        "make",
    } },
}

for _, group in ipairs(indent_groups) do
    local ts, sw, et, fts = unpack(group)
    vim.api.nvim_create_autocmd("FileType", {
        group = indent_augroup,
        pattern = fts,
        callback = function(args)
            -- Project .editorconfig wins: re-apply its indent values after a
            -- late FileType handler, otherwise apply the defaults.
            if util.has_editorconfig_indent(args.buf) then
                util.reapply_editorconfig_indent(args.buf)
                return
            end
            vim.opt_local.tabstop = ts
            vim.opt_local.shiftwidth = sw
            vim.opt_local.softtabstop = sw
            vim.opt_local.expandtab = et
        end,
    })
end

-- ── C / C++: Google Style defaults, project .clang-format overrides ──
-- clang-format's fallback style is Google (see plugins/conform.lua), so the
-- editor matches it by default: 2-space indent. A project .clang-format
-- (searched upward from the buffer) overrides that via its IndentWidth /
-- TabWidth / UseTab / BasedOnStyle keys. Project .editorconfig keeps
-- precedence over both.

local CLANG_FORMAT_STYLES = {
    LLVM = { indent = 2, tabwidth = 8, use_tab = false },
    GNU = { indent = 2, tabwidth = 8, use_tab = false },
    Google = { indent = 2, tabwidth = 8, use_tab = false },
    Chromium = { indent = 2, tabwidth = 8, use_tab = false },
    Mozilla = { indent = 2, tabwidth = 8, use_tab = false },
    WebKit = { indent = 4, tabwidth = 8, use_tab = false },
    Microsoft = { indent = 4, tabwidth = 4, use_tab = false },
}

---Parse a .clang-format file for the indentation-relevant keys.
---@param path string
---@return table|nil {indent, tabwidth, use_tab}
local function parse_clang_format(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local based_on, indent, tabwidth, use_tab
    for line in file:lines() do
        line = line:gsub("#.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:match("^%-%-%-") and not line:match("^%.%.%.") then
            local key, val = line:match("^([%w_]+)%s*:%s*(.-)%s*$")
            if key and val ~= "" then
                if key == "BasedOnStyle" then
                    based_on = val
                elseif key == "IndentWidth" then
                    indent = tonumber(val)
                elseif key == "TabWidth" then
                    tabwidth = tonumber(val)
                elseif key == "UseTab" then
                    local v = val:lower()
                    use_tab = v == "always" or v == "forindentation" or v == "true"
                end
            end
        end
    end
    file:close()
    local base = (based_on and CLANG_FORMAT_STYLES[based_on]) or CLANG_FORMAT_STYLES.Google
    return {
        indent = indent or base.indent,
        tabwidth = tabwidth or base.tabwidth,
        use_tab = use_tab or base.use_tab,
    }
end

---Locate the nearest .clang-format above the buffer's directory.
---@param bufnr integer
---@return string|nil
local function find_clang_format(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then return nil end
    local found = vim.fs.find(".clang-format", { upward = true, path = vim.fn.fnamemodify(name, ":h") })
    return found[1]
end

vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("indent_clang", { clear = true }),
    pattern = { "c", "cpp", "objc", "objcpp" },
    callback = function(args)
        -- Project .editorconfig wins over everything else.
        if util.has_editorconfig_indent(args.buf) then
            util.reapply_editorconfig_indent(args.buf)
            return
        end
        local cf = find_clang_format(args.buf)
        local ind = cf and parse_clang_format(cf)
        if ind then
            vim.opt_local.tabstop = ind.tabwidth
            vim.opt_local.shiftwidth = ind.indent
            vim.opt_local.softtabstop = ind.indent
            vim.opt_local.expandtab = not ind.use_tab
            return
        end
        -- Google default: 2-space indent
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.softtabstop = 2
        vim.opt_local.expandtab = true
    end,
})
