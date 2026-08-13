-- ~/.config/nvim/lua/config/autocmds.lua
-- Autocommands

-- Highlight on yank/paste
-- Uses vim.hl.hl_op (Neovim ≥ 0.13) with fallback to vim.hl.on_yank (0.12.x)
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

-- Restore last cursor position on file open
vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("last_position", { clear = true }),
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
    end,
})

-- =============================================
-- Per-filetype indentation
-- =============================================
-- Global defaults in options.lua: 4-space indent, expandtab.
-- Only non-default filetypes are overridden here.
-- Unlisted filetypes inherit the global default.
--
-- Project .editorconfig values take precedence: Neovim's runtime applies
-- them on file open (plugin/editorconfig.lua), and the FileType callback
-- below re-asserts them whenever a late FileType event lets runtime
-- ftplugin/indent handlers overwrite the project values.

local indent_augroup = vim.api.nvim_create_augroup("indent_settings", { clear = true })

-- Indent config groups: [tabstop, shiftwidth, expandtab, filetypes]
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

    -- Tab indent — toolchains that mandate tabs
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
            -- Project .editorconfig wins: re-assert its indent values after
            -- any runtime ftplugin/indent handlers, otherwise apply defaults.
            local editorconfig = require("config.editorconfig")
            if editorconfig.has_indent(args.buf) then
                editorconfig.reapply_indent(args.buf)
                return
            end
            vim.opt_local.tabstop = ts
            vim.opt_local.shiftwidth = sw
            vim.opt_local.expandtab = et
        end,
    })
end
