-- LSP config (native Neovim 0.11+ API): per-server config tables, diagnostics,
-- native completion activation, and LSP keymaps.
--
-- Mason is initialized synchronously in the plugin phase (plugins/mason.lua,
-- loaded before this module) and only installs servers; this module registers
-- native vim.lsp.config() overrides, enables servers, and wires up completion.

local util = require("config.util")

local M = {}

-- ── Diagnostics ──
vim.diagnostic.config({
    virtual_text = true,
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.INFO] = "",
            [vim.diagnostic.severity.HINT] = "",
        },
    },
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

-- ── Per-server configs ──
-- Keys match the mason-lspconfig registry; missing fields (e.g. cmd) are filled
-- by nvim-lspconfig defaults.
local server_configs = {
    bashls = {
        -- Bash language server: covers POSIX shell and Bash buffers.
        filetypes = { "sh", "bash" },
        root_markers = { ".git", "Makefile", "package.json" },
        settings = {
            bashIde = { globPattern = "**/*@(.sh|.inc|.bash|.command)" },
        },
    },

    clangd = {
        -- C / C++ / Objective-C: formatting belongs to conform.nvim,
        -- clangd only handles analysis and navigation.
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
        -- VS Code CSS language server: CSS / SCSS / Less validation stays on.
        filetypes = { "css", "scss", "less" },
        root_markers = { "package.json", ".git" },
        settings = {
            css = { validate = true },
            scss = { validate = true },
            less = { validate = true },
        },
    },

    gopls = {
        -- Go modules and workspaces: static analysis runs continuously,
        -- formatting belongs to conform.nvim.
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
        -- VS Code HTML language server: extra template filetypes share
        -- completion and validation.
        filetypes = { "html", "handlebars", "htmldjango" },
        root_markers = { "package.json", ".git" },
        init_options = { provideFormatter = false },
    },

    jsonls = {
        -- VS Code JSON language server: schema download and validation on,
        -- formatting belongs to conform.
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
        -- Official Kotlin language server: Gradle / Maven markers scope
        -- projects.
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
        -- Neovim Lua development: index runtime APIs, no third-party config hints.
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
        -- Python: workspace-level diagnostics catch cross-file issues.
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
        -- Cargo projects: Clippy handles save-time checks, rustfmt belongs
        -- to the Rust toolchain.
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
        -- TypeScript / JavaScript: single-file mode lets small scripts work
        -- outside a package root.
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
        root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
        single_file_support = true,
        init_options = { hostInfo = "neovim" },
    },

    yamlls = {
        -- Red Hat YAML language server: enable the Schema Store, don't
        -- hardcode project schemas.
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

-- Enable servers uniformly once all native overrides are registered
-- (in tool-list order).
for _, server in ipairs(util.lsp_servers) do
    vim.lsp.enable(server)
end

-- ── Native completion ──
-- Completion is enabled per attached client; Markdown is deliberately excluded
-- so plain-text buffers pay no cost for completion requests and popups.

local function is_markdown(bufnr) return vim.bo[bufnr].filetype == "markdown" end

-- Every-keystroke autotrigger state, flipped by <leader>uc (keymaps.lua).
-- New LspAttach events respect it; toggling re-applies it to what is
-- already attached.
local autotrigger = true

--- Enable native completion for one LspAttach event.
---@param args { buf: integer, data: { client_id: integer } }
---@return boolean whether completion was enabled
function M.enable_for_client(args)
    if is_markdown(args.buf) then return false end

    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/completion", args.buf) then
        -- autotrigger only fires on the server's triggerCharacters, which are
        -- typically just ".", ":", ">", etc. Extend them to all printable
        -- non-space ASCII (33-126) so the popup opens on every keystroke.
        -- completeopt=noselect/noinsert (set in config/options.lua) still keeps
        -- the menu from pre-selecting or auto-inserting an item.
        local cp = client.server_capabilities.completionProvider
        if cp then
            local chars = {}
            for i = 33, 126 do
                table.insert(chars, string.char(i))
            end
            cp.triggerCharacters = chars
        end
        vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = autotrigger })
        return true
    end
    return false
end

---<C-Space> behavior: request completion in code buffers, stay silent in Markdown.
---@return boolean whether a completion request was issued
function M.trigger()
    if vim.bo.filetype == "markdown" then return false end
    vim.lsp.completion.get()
    return true
end

--- <leader>uc: flip the every-keystroke autotrigger on every attached
--- client/buffer. The shared InsertCharPre autocmds die only when the LAST
--- completion client leaves a buffer, so switching needs a full teardown
--- pass per buffer before rebuilding through enable_for_client();
--- <C-Space> keeps working in both states.
function M.toggle_autotrigger()
    autotrigger = not autotrigger
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            local clients = {}
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
                if client:supports_method("textDocument/completion", bufnr) then clients[#clients + 1] = client end
            end
            for _, client in ipairs(clients) do
                vim.lsp.completion.enable(false, client.id, bufnr)
            end
            for _, client in ipairs(clients) do
                M.enable_for_client({ buf = bufnr, data = { client_id = client.id } })
            end
        end
    end
    vim.notify(
        "Completion autotrigger " .. (autotrigger and "on" or "off (<C-Space> still works)"),
        vim.log.levels.INFO
    )
end

--- Register an LspAttach autocmd that activates completion per client.
function M.register()
    vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp_completion", { clear = true }),
        callback = M.enable_for_client,
    })
end

-- ── LSP keymaps ──
-- Deliberately global: vim.lsp.buf.* shows a native "no client" hint in buffers
-- without an attached client.
util.map("i", "<C-Space>", M.trigger, "Trigger completion")
util.map("n", "<leader>ld", vim.lsp.buf.definition, "Go to definition")
util.map("n", "<leader>lh", function() vim.lsp.buf.hover({ border = "rounded" }) end, "Hover docs")
util.map("n", "<leader>lR", vim.lsp.buf.references, "Find references")
util.map("n", "<leader>lr", vim.lsp.buf.rename, "Rename symbol")
util.map("n", "<leader>la", vim.lsp.buf.code_action, "Code actions")
util.map("n", "<leader>li", vim.lsp.buf.implementation, "Go to implementation")
util.map("n", "<leader>ls", function() require("fzf-lua").lsp_document_symbols() end, "Document symbols")
util.map("n", "<leader>lS", function() require("fzf-lua").lsp_workspace_symbols() end, "Workspace symbols")
util.map("n", "<leader>lI", function() vim.lsp.buf.signature_help({ border = "rounded" }) end, "Signature help")

M.register()

return M
