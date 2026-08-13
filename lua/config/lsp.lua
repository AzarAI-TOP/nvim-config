-- LSP 配置（Neovim 0.11+ 原生 API）：各服务器配置表、诊断显示、
-- 原生补全激活与 LSP 键位。
--
-- Mason 已在插件阶段同步初始化（plugins/mason.lua，先于本模块加载），
-- 只负责安装服务器；本模块注册原生 vim.lsp.config() 覆盖、启用服务器，
-- 并接入补全。mason-lspconfig 的包名映射仅被健康检查和 first-boot 测试使用。

local util = require("config.util")

local M = {}

-- ── 诊断显示 ──
vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
        border = "rounded",
        source = "if_many",
        header = "",
        prefix = "",
    },
})

-- ── 各服务器配置 ──
-- 键名与 mason-lspconfig 注册表一致；缺失的字段（如 cmd）由
-- nvim-lspconfig 的默认配置补齐。
local server_configs = {
    bashls = {
        -- Bash 语言服务器：覆盖 POSIX shell 与 Bash 缓冲区。
        filetypes = { "sh", "bash" },
        root_markers = { ".git", "Makefile", "package.json" },
        settings = {
            bashIde = { globPattern = "**/*@(.sh|.inc|.bash|.command)" },
        },
    },

    clangd = {
        -- C / C++ / Objective-C：格式化归 conform.nvim 管，
        -- clangd 只负责分析与导航。
        cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--completion-style=detailed",
            "--header-insertion=never",
        },
        filetypes = { "c", "cpp", "objc", "objcpp" },
        root_markers = { "compile_commands.json", "compile_flags.txt", ".clangd", ".git" },
    },

    cssls = {
        -- VS Code CSS 语言服务器：CSS / SCSS / Less 校验保持开启。
        filetypes = { "css", "scss", "less" },
        root_markers = { "package.json", ".git" },
        settings = {
            css = { validate = true },
            scss = { validate = true },
            less = { validate = true },
        },
    },

    gopls = {
        -- Go 模块与工作区：静态分析持续运行，格式化归 conform.nvim。
        root_markers = { "go.work", "go.mod", ".git" },
        settings = {
            gopls = {
                analyses = { unusedparams = true, unusedwrite = true },
                completeUnimported = true,
                gofumpt = false,
                semanticTokens = true,
                staticcheck = true,
                usePlaceholders = true,
            },
        },
    },

    html = {
        -- VS Code HTML 语言服务器：额外模板文件类型共享补全与校验。
        filetypes = { "html", "handlebars", "htmldjango" },
        root_markers = { "package.json", ".git" },
        init_options = { provideFormatter = false },
    },

    jsonls = {
        -- VS Code JSON 语言服务器：schema 下载与校验开启，格式化归 conform。
        cmd = { "vscode-json-language-server", "--stdio" },
        root_markers = { "package.json", ".git" },
        settings = {
            json = {
                format = { enable = false },
                schemaDownload = { enable = true },
                validate = { enable = true },
            },
        },
    },

    kotlin_lsp = {
        -- 官方 Kotlin 语言服务器：Gradle / Maven 标记限定项目范围。
        root_markers = {
            "settings.gradle.kts",
            "settings.gradle",
            "build.gradle.kts",
            "build.gradle",
            "pom.xml",
            ".git",
        },
        settings = { kotlin = { compiler = { jvm = { target = "21" } } } },
    },

    lua_ls = {
        -- Neovim Lua 开发：索引运行时 API，不提示第三方库配置。
        root_markers = { ".luarc.json", ".luarc.jsonc", "stylua.toml", ".stylua.toml", ".git" },
        settings = {
            Lua = {
                completion = { callSnippet = "Replace" },
                diagnostics = { globals = { "vim" } },
                runtime = { version = "LuaJIT" },
                telemetry = { enable = false },
                workspace = {
                    checkThirdParty = false,
                    library = { vim.env.VIMRUNTIME, vim.fn.stdpath("data") .. "/site" },
                },
            },
        },
    },

    pyright = {
        -- Python：工作区级诊断捕捉跨文件问题。
        root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
        settings = {
            python = {
                analysis = {
                    autoImportCompletions = true,
                    autoSearchPaths = true,
                    diagnosticMode = "workspace",
                    typeCheckingMode = "basic",
                    useLibraryCodeForTypes = true,
                },
            },
        },
    },

    rust_analyzer = {
        -- Cargo 项目：Clippy 负责保存时检查，rustfmt 归 Rust 工具链。
        root_markers = { "Cargo.toml", "rust-project.json", ".git" },
        settings = {
            ["rust-analyzer"] = {
                cargo = { allFeatures = true },
                check = { command = "clippy" },
                completion = { callable = { snippets = "add_parentheses" } },
                procMacro = { enable = true },
            },
        },
    },

    ts_ls = {
        -- TypeScript / JavaScript：单文件模式让小脚本脱离包根也能用。
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
        root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
        single_file_support = true,
        init_options = { hostInfo = "neovim" },
    },

    yamlls = {
        -- Red Hat YAML 语言服务器：启用 Schema Store，不硬编码项目 schema。
        root_markers = { ".yamllint", ".git" },
        settings = {
            redhat = { telemetry = { enabled = false } },
            yaml = {
                schemaStore = { enable = true },
                validate = true,
            },
        },
    },
}

for name, config in pairs(server_configs) do
    vim.lsp.config(name, config)
end

-- 原生覆盖全部注册完成后，统一启用服务器（按工具清单顺序）。
for _, server in ipairs(util.lsp_servers) do
    vim.lsp.enable(server)
end

-- ── 原生补全 ──
-- 每个附着的客户端单独启用补全；Markdown 刻意排除，
-- 让纯文本缓冲区不为补全请求和弹窗付出任何代价。

local function is_markdown(bufnr) return vim.bo[bufnr].filetype == "markdown" end

---为一次 LspAttach 事件启用原生补全。
---@param args { buf: integer, data: { client_id: integer } }
---@return boolean 是否已启用
function M.enable_for_client(args)
    if is_markdown(args.buf) then return false end

    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/completion", args.buf) then
        vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
        return true
    end
    return false
end

---<C-Space> 的行为：代码缓冲区请求补全，Markdown 中保持静默。
---@return boolean 是否发出了补全请求
function M.trigger()
    if vim.bo.filetype == "markdown" then return false end
    vim.lsp.completion.get()
    return true
end

---注册 LspAttach autocmd，按客户端激活补全。
function M.register()
    vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_completion", { clear = true }),
        callback = M.enable_for_client,
    })
end

-- ── LSP 键位 ──
-- 刻意注册为全局键位：vim.lsp.buf.* 在未附着客户端的缓冲区中
-- 会给出原生"无客户端"提示。
util.map("i", "<C-Space>", M.trigger, "触发补全")
util.map("n", "<leader>ld", vim.lsp.buf.definition, "跳转到定义")
util.map("n", "<leader>lh", function() vim.lsp.buf.hover({ border = "rounded" }) end, "悬浮文档")
util.map("n", "<leader>lr", vim.lsp.buf.references, "查找引用")
util.map("n", "<leader>lR", vim.lsp.buf.rename, "重命名符号")
util.map("n", "<leader>la", vim.lsp.buf.code_action, "代码操作")
util.map("n", "<leader>li", vim.lsp.buf.implementation, "跳转到实现")
util.map("n", "<leader>ls", function() vim.lsp.buf.signature_help({ border = "rounded" }) end, "签名帮助")

M.register()

return M
