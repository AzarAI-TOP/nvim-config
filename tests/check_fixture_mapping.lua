local fixtures = {
    bashls = { file = "sample.sh", filetype = "sh" },
    clangd = { file = "sample.cpp", filetype = "cpp" },
    cssls = { file = "sample.css", filetype = "css" },
    gopls = { file = "sample.go", filetype = "go" },
    html = { file = "sample.html", filetype = "html" },
    jsonls = { file = "sample.json", filetype = "json" },
    kotlin_lsp = { file = "sample.kt", filetype = "kotlin" },
    lua_ls = { file = "sample.lua", filetype = "lua" },
    pyright = { file = "sample.py", filetype = "python" },
    rust_analyzer = { file = "sample.rs", filetype = "rust" },
    ts_ls = { file = "sample.ts", filetype = "typescript" },
    yamlls = { file = "sample.yaml", filetype = "yaml" },
}

local root = vim.fs.joinpath(vim.fn.stdpath("config"), "tests", "fixtures")
local failures = {}
for server, fixture in pairs(fixtures) do
    local path = vim.fs.joinpath(root, fixture.file)
    if vim.fn.filereadable(path) ~= 1 then table.insert(failures, server .. " fixture missing: " .. fixture.file) end
    local config = vim.lsp.config[server]
    if not config or not vim.tbl_contains(config.filetypes or {}, fixture.filetype) then
        table.insert(failures, server .. " fixture filetype is not mapped: " .. fixture.filetype)
    end
end

if #failures > 0 then
    io.stderr:write("FIXTURE_MAPPING_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("FIXTURE_MAPPING_CHECK_OK servers=" .. vim.tbl_count(fixtures) .. "\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
