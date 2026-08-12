-- Clangd configuration for C, C++, Objective-C, and Objective-C++.
-- Formatting is owned by conform.nvim; clangd supplies analysis and navigation.
return {
    cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--completion-style=detailed",
        "--header-insertion=never",
    },
    filetypes = { "c", "cpp", "objc", "objcpp" },
    root_markers = { "compile_commands.json", "compile_flags.txt", ".clangd", ".git" },
}
