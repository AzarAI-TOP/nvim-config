-- ~/.config/nvim/lua/plugins/conform.lua
-- Code formatting (conform.nvim, via vim.pack)
--
-- conform does not install formatters — they must be on PATH (Mason handles this).
-- Missing formatters are silently skipped per filetype.

vim.pack.add({
    { src = "https://github.com/stevearc/conform.nvim" },
})

require("conform").setup({
    formatters_by_ft = {
        lua = { "stylua" },
        python = { "isort", "black" },
        rust = { "rustfmt" },
        go = { "goimports", "gofmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        java = { "google-java-format" },
        kotlin = { "ktlint" },
        -- prettierd covers web / markup / declarative languages
        javascript = { "prettierd" },
        javascriptreact = { "prettierd" },
        typescript = { "prettierd" },
        typescriptreact = { "prettierd" },
        html = { "prettierd" },
        css = { "prettierd" },
        scss = { "prettierd" },
        json = { "prettierd" },
        jsonc = { "prettierd" },
        yaml = { "prettierd" },
        -- No markdown formatter — preserves typing speed in prose.
        sh = { "shfmt" },
        bash = { "shfmt" },
        toml = { "taplo" },
    },

    -- Custom formatter options.
    -- These override the default arguments passed to each formatter.
    formatters = {
        shfmt = {
            -- Use 4-space indentation (default is tab).
            prepend_args = { "-i", "4" },
        },
        ["clang-format"] = {
            -- Google Style: 2-space indent, 80-col, specific bracket placement.
            prepend_args = { "--style=Google" },
        },
        -- prettierd automatically reads .prettierrc from the project root.
        -- No explicit config needed — prettierd resolves it natively.
    },
})
