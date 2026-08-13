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
    -- 2 spaces — web / scripting / markup / declarative languages
    {
        2,
        2,
        true,
        {
            "lua",
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
            "sh",
            "bash",
            "zsh",
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
        },
    },

    -- 4 spaces — systems / traditional languages
    {
        4,
        4,
        true,
        {
            "python",
            "rust",
            "c",
            "cpp",
            "java",
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
            vim.opt_local.expandtab = et
        end,
    })
end
