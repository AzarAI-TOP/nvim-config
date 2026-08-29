-- Code formatting (conform.nvim, via vim.pack)
--
-- conform does not install formatters — they must be on PATH (Mason's job).
-- Missing formatters are skipped silently per filetype.

vim.pack.add({
    { src = "https://github.com/stevearc/conform.nvim" },
})

require("conform").setup({
    formatters_by_ft = {
        lua = { "stylua" },
        python = { "isort", "black" },
        rust = { "rustfmt" },
        -- goimports output is already gofmt-formatted; a second pass would
        -- just spawn a redundant process
        go = { "goimports" },
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
        -- svelte is deliberately absent: prettierd does not bundle
        -- prettier-plugin-svelte, so a svelte entry would fail on format.
        vue = { "prettierd" },
        graphql = { "prettierd" },
        json = { "prettierd" },
        jsonc = { "prettierd" },
        yaml = { "prettierd" },
        -- Markdown gets no formatter — keep prose input immediate
        sh = { "shfmt" },
        bash = { "shfmt" },
        toml = { "taplo" },
    },

    -- Custom formatter arguments: override each formatter's defaults.
    formatters = {
        shfmt = {
            -- Pin 4-space indentation, ignoring buffer-local defaults and the
            -- project .editorconfig
            args = { "-filename", "$FILENAME", "-i", "4" },
        },
        isort = {
            -- Avoid isort 8's stricter --line-ending parsing; stdin keeps the
            -- buffer's existing line endings while still honoring project config
            args = { "--stdout", "--filename", "$FILENAME", "-" },
        },
        ["clang-format"] = {
            -- Prefer a project .clang-format when present; Google Style is only
            -- the fallback for files outside configured projects
            prepend_args = { "--fallback-style=Google" },
        },
        prettierd = {
            -- Prefer a project .prettierrc / prettier.config when present;
            -- otherwise use Prettier's built-in defaults
            require_cwd = false,
        },
    },
})
