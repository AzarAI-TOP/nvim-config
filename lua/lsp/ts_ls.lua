-- ~/.config/nvim/lua/lsp/ts_ls.lua
-- TypeScript Language Server configuration
return {
    filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
    settings = {},
}
