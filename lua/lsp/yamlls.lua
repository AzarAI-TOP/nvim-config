-- Red Hat YAML Language Server configuration.
-- Schema Store support is enabled without hard-coding project-specific schemas.
return {
    root_markers = { ".yamllint", ".git" },
    settings = {
        redhat = { telemetry = { enabled = false } },
        yaml = {
            schemaStore = { enable = true },
            validate = true,
        },
    },
}
