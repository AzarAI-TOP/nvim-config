-- rust-analyzer configuration for Cargo projects.
-- Clippy powers on-save checks; rustfmt remains owned by the Rust toolchain.
return {
    root_markers = { "Cargo.toml", "rust-project.json", ".git" },
    settings = {
        ["rust-analyzer"] = {
            cargo = { allFeatures = true },
            check = { command = "clippy" },
            completion = { callable = { snippets = "add_parentheses" } },
            procMacro = { enable = true },
        },
    },
}
