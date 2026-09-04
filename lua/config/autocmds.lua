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
-- (searched upward from the buffer) overrides that by asking clang-format
-- itself: `--dump-config` prints the fully resolved config — BasedOnStyle and
-- every inheritance already expanded — so reading the three indentation keys
-- from its flat output is exact, unlike regex-parsing the raw project file.
-- The dump runs asynchronously (the buffer keeps the Google default until it
-- lands, ~100ms) and is cached per .clang-format file, keyed by mtime.
-- Project .editorconfig keeps precedence over everything.

---Apply one indentation spec to a buffer.
---@param bufnr integer
---@param indent integer
---@param tabwidth integer
---@param use_tab boolean
local function apply_clang_indent(bufnr, indent, tabwidth, use_tab)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    vim.bo[bufnr].shiftwidth = indent
    vim.bo[bufnr].softtabstop = indent
    vim.bo[bufnr].tabstop = tabwidth
    vim.bo[bufnr].expandtab = not use_tab
end

---Read the three indentation keys from a resolved --dump-config output.
---Top-level YAML in the dump is flat ("IndentWidth: 4"); the anchored
---patterns cannot match inside nested sections.
---@param dump string
---@return { indent: integer, tabwidth: integer, use_tab: boolean }|nil
local function parse_dump(dump)
    local indent, tabwidth, use_tab
    for line in dump:gmatch("[^\r\n]+") do
        local n = line:match("^IndentWidth:%s+(%d+)")
        if n then indent = tonumber(n) end
        n = line:match("^TabWidth:%s+(%d+)")
        if n then tabwidth = tonumber(n) end
        local t = line:match("^UseTab:%s+(%S+)")
        -- Match the old hand parser's semantics: only Always/ForIndentation
        -- mean tab indentation; Never/false (and ForContinuation, which uses
        -- tabs only for alignment continuations) keep expandtab.
        if t then use_tab = t == "Always" or t == "ForIndentation" end
    end
    if not indent then return nil end
    return { indent = indent, tabwidth = tabwidth or indent, use_tab = use_tab or false }
end

-- dump cache: .clang-format path -> { mtime: integer, opts: table }
local clang_dumps = {}

---Apply the project .clang-format's resolved indentation to the buffer.
---One retry when clang-format is not on PATH yet (a C file opened before
---Mason's bin joined PATH); LLVM's system install normally resolves at once.
local function apply_from_clang_format(bufnr, path, retry)
    local mtime = vim.fn.getftime(path)
    local cached = clang_dumps[path]
    if cached and cached.mtime == mtime then
        apply_clang_indent(bufnr, cached.opts.indent, cached.opts.tabwidth, cached.opts.use_tab)
        return
    end
    if vim.fn.executable("clang-format") == 0 then
        if not retry then vim.defer_fn(function() apply_from_clang_format(bufnr, path, true) end, 2000) end
        return
    end
    vim.system(
        { "clang-format", "--dump-config", "--style=file:" .. path:gsub("\\", "/") },
        { text = true },
        function(obj)
            if obj.code ~= 0 then return end
            local opts = parse_dump(obj.stdout)
            if not opts then return end
            clang_dumps[path] = { mtime = mtime, opts = opts }
            vim.schedule(function() apply_clang_indent(bufnr, opts.indent, opts.tabwidth, opts.use_tab) end)
        end
    )
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
        if cf then
            -- Google default until the dump lands (or forever on dump failure).
            vim.opt_local.tabstop = 2
            vim.opt_local.shiftwidth = 2
            vim.opt_local.softtabstop = 2
            vim.opt_local.expandtab = true
            apply_from_clang_format(args.buf, cf, false)
            return
        end
        -- Google default: 2-space indent
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.softtabstop = 2
        vim.opt_local.expandtab = true
    end,
})
