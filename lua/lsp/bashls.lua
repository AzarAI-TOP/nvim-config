-- Bash Language Server configuration.
-- Covers POSIX shell and Bash buffers; project roots prefer common shell repos.
return {
    filetypes = { "sh", "bash" },
    root_markers = { ".git", "Makefile", "package.json" },
    settings = {
        bashIde = { globPattern = "**/*@(.sh|.inc|.bash|.command)" },
    },
}
