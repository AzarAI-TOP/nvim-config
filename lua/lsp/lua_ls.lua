-- Lua Language Server configuration for Neovim Lua development.
-- Neovim runtime APIs are indexed without prompting for third-party setup.
return {
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
}
