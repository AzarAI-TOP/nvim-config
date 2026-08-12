-- TypeScript Language Server configuration for JavaScript and TypeScript.
-- Single-file support keeps small scripts useful outside a package root.
return {
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
    single_file_support = true,
    init_options = { hostInfo = "neovim" },
}
