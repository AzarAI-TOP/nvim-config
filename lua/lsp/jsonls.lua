-- ~/.config/nvim/lua/lsp/jsonls.lua
-- JSON Language Server configuration
return {
    cmd = { "vscode-json-language-server", "--stdio", "--provide-formatter" },
    root_markers = { "package.json", ".git" },
    settings = {
        json = {
            format = { enable = true },
            validate = { enable = true },
            schemaDownload = { enable = true },
            suggest = {
                parentSkeletonShownFirst = true,
                paths = {},
            },
            proposeAlts = true,
        },
    },
}
