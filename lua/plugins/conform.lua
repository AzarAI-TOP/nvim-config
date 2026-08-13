-- 代码格式化（conform.nvim，经 vim.pack）
--
-- conform 不安装格式化器——它们必须位于 PATH 上（由 Mason 负责）。
-- 缺失的格式化器按文件类型静默跳过。

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
        -- prettierd 覆盖 Web / 标记 / 声明式语言
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
        -- Markdown 不配格式化器 — 保持行文输入的即时性
        sh = { "shfmt" },
        bash = { "shfmt" },
        toml = { "taplo" },
    },

    -- 自定义格式化器参数：覆盖各格式化器的默认参数。
    formatters = {
        shfmt = {
            -- 固定 4 空格缩进，忽略缓冲区本地默认与项目 .editorconfig
            args = { "-filename", "$FILENAME", "-i", "4" },
        },
        isort = {
            -- 规避 isort 8 更严格的 --line-ending 解析；stdin 保留
            -- 缓冲区现有行尾，同时仍遵循项目配置
            args = { "--stdout", "--filename", "$FILENAME", "-" },
        },
        ["clang-format"] = {
            -- 项目 .clang-format 存在时优先；Google Style 仅作为
            -- 未配置项目之外文件的回退
            prepend_args = { "--fallback-style=Google" },
        },
        prettierd = {
            -- 存在项目 .prettierrc / prettier.config 时优先；
            -- 否则使用 Prettier 内建默认值
            require_cwd = false,
        },
    },
})
