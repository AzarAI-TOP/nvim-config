-- VS Code CSS Language Server configuration.
-- Validation remains enabled for CSS, SCSS, and Less project files.
return {
    filetypes = { "css", "scss", "less" },
    root_markers = { "package.json", ".git" },
    settings = {
        css = { validate = true },
        scss = { validate = true },
        less = { validate = true },
    },
}
