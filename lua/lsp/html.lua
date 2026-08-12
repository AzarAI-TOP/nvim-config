-- VS Code HTML Language Server configuration.
-- Extra template filetypes share HTML completion and validation support.
return {
    filetypes = { "html", "handlebars", "htmldjango" },
    root_markers = { "package.json", ".git" },
    init_options = { provideFormatter = false },
}
