-- Extra filetype detection for names Neovim's runtime doesn't define but
-- nvim-lspconfig server configs list: yamlls serves yaml.gitlab,
-- yaml.docker-compose and yaml.helm-values, gopls serves gotmpl. Without
-- detection producing those names the servers never attach to the files they
-- describe (and :checkhealth vim.lsp flags them as unknown filetypes).
--
-- Pattern notes: vim.filetype.add() anchors every pattern as ^pattern$ and,
-- when the pattern has no '/', matches it against the basename only — so the
-- keys below are written as whole-basename patterns. The derived yaml.* names
-- keep working everywhere plain yaml does:
--   - treesitter: language.register below maps them onto the yaml parser
--   - conform:    formatters_by_ft lists them (plugins/conform.lua)
--   - indent:     the 2-space yaml group covers them (config/autocmds.lua)

vim.filetype.add({
    pattern = {
        -- GitLab CI: .gitlab-ci.yml / .gitlab-ci.yaml
        ["%.gitlab%-ci%.ya?ml"] = "yaml.gitlab",
        -- Docker Compose spec: compose.yaml / docker-compose[.override].yml
        ["docker%-compose.*%.ya?ml"] = "yaml.docker-compose",
        ["compose%.ya?ml"] = "yaml.docker-compose",
        -- Go templates (gopls lists the gotmpl filetype)
        [".*%.gotmpl"] = "gotmpl",
        -- Helm values files: values.y[a]ml / values-<name>.y[a]ml. The bare
        -- name is ambiguous (any project can have a values.yaml), so the
        -- mapping is a function: only files with a Chart.yaml at/above them
        -- (helm chart layout) become yaml.helm-values. No chart -> nil ->
        -- falls through to plain yaml detection. (Pattern must not contain
        -- "/" — even inside a character class — or filetype.lua treats it as
        -- a path pattern and matches the full path instead of the basename.)
        ["values[%w%-_]*%.ya?ml"] = function(path)
            local chart = vim.fs.find("Chart.yaml", { upward = true, path = vim.fs.dirname(path) })
            if #chart > 0 then return "yaml.helm-values" end
        end,
    },
})

-- The yaml.* pseudo-filetypes share the yaml treesitter parser (the FileType
-- highlight autocmd in plugins/treesitter.lua resolves them through this).
vim.treesitter.language.register("yaml", { "yaml.gitlab", "yaml.docker-compose", "yaml.helm-values" })
