-- ~/.config/nvim/lua/lsp/clangd.lua
-- Clangd Language Server configuration
--
-- C/C++ language server. Uses Google style for formatting.
return {
    cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--header-insertion=never",
    },
    filetypes = { "c", "cpp", "objc", "objcpp" },
    root_markers = { "compile_commands.json", "compile_flags.txt", ".git" },
    settings = {},
}
