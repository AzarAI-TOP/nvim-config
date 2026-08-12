-- gopls configuration for Go modules and workspaces.
-- Static analysis runs continuously; formatting remains owned by conform.nvim.
return {
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
}
