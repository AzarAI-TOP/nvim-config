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
            -- Use 4-space indentation regardless of buffer-local defaults or
            -- project .editorconfig values.
            args = { "-filename", "$FILENAME", "-i", "4" },
        },
        isort = {
            -- Avoid isort 8's stricter --line-ending parsing; stdin keeps the
            -- buffer's existing line endings and still honors project config.
            args = { "--stdout", "--filename", "$FILENAME", "-" },
        },
        ["clang-format"] = {
            -- Google Style: 2-space indent, 80-col, specific bracket placement.
            prepend_args = { "--style=Google" },
        },
        prettierd = {
            -- Conform locates .prettierrc (or another supported project config)
            -- and supplies that directory as cwd. Refuse to format without one
            -- so personal/global defaults never silently rewrite project files.
            require_cwd = true,
        },
    },
})
