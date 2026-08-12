-- VS Code JSON Language Server configuration.
-- Schema downloads and validation are enabled; formatting is owned by Conform.
return {
    cmd = { "vscode-json-language-server", "--stdio" },
    root_markers = { "package.json", ".git" },
    settings = {
        json = {
            format = { enable = false },
            schemaDownload = { enable = true },
            validate = { enable = true },
        },
    },
}
