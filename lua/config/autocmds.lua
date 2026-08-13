-- 自动命令：高亮闪烁、光标位置恢复、按文件类型的缩进规则。

local util = require("config.util")

-- ── 复制 / 粘贴高亮 ──
-- 优先 vim.hl.hl_op（Neovim ≥ 0.13），回退到 vim.hl.on_yank（0.12.x）。
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

-- ── 打开文件时恢复上次光标位置 ──
vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("last_position", { clear = true }),
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
    end,
})

-- ── 按文件类型的缩进 ──
-- 全局默认在 options.lua：4 空格、expandtab；此处只覆盖非默认文件类型，
-- 未列出的文件类型沿用全局默认。
--
-- 项目 .editorconfig 优先：运行时在文件打开时应用它（plugin/editorconfig.lua），
-- 下方的 FileType 回调在迟到的 FileType 事件让 ftplugin/indent 处理器
-- 覆盖项目值之后，重新把项目值扶正。

local indent_augroup = vim.api.nvim_create_augroup("indent_settings", { clear = true })

-- 缩进组格式：[tabstop, shiftwidth, expandtab, 文件类型列表]
local indent_groups = {
    -- 2 空格 — Web / 脚本 / 标记 / 声明式语言
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

    -- 4 空格 — 系统 / 传统语言
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

    -- Tab 缩进 — 强制使用 Tab 的工具链
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
            -- 项目 .editorconfig 优先：迟到的 FileType 处理器之后重新应用
            -- 其缩进值，否则应用默认值。
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
