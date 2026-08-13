-- Integration check for a fully bootstrapped environment.
-- Tests multiple LSP servers and formatters against real fixture content.
-- Run after Mason installation in a disposable XDG environment.

local function verify_runtime()
    if vim.env.NVIM_FORCE_RUNTIME_TEST_FAILURE == "1" then error("forced runtime test failure") end

    local results = {}
    local failures = {}
    local tested_formatters = {}

    -- Helper: test a formatter on a scratch buffer.
    local function test_formatter(ft, bad_lines, expected_substring, formatter_name, formatters)
        for _, f in ipairs(formatters or { formatter_name }) do
            tested_formatters[f] = true
        end
        local scratch = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(scratch)
        vim.bo[scratch].filetype = ft
        vim.api.nvim_buf_set_lines(scratch, 0, -1, false, bad_lines)

        local finished, format_error, did_edit = false, nil, nil
        require("conform").format(
            { bufnr = scratch, async = true, formatters = formatters or { formatter_name } },
            function(err, edited)
                format_error, did_edit, finished = err, edited, true
            end
        )
        assert(vim.wait(15000, function() return finished end, 50), formatter_name .. " callback timed out")

        if format_error then
            table.insert(failures, formatter_name .. " error: " .. tostring(format_error))
        elseif not did_edit then
            table.insert(failures, formatter_name .. " did not edit buffer")
        else
            local formatted = table.concat(vim.api.nvim_buf_get_lines(scratch, 0, -1, false), "\n")
            if formatted:find(expected_substring, 1, true) then
                table.insert(results, formatter_name .. "=ok")
            else
                table.insert(failures, formatter_name .. " output unexpected: " .. formatted)
            end
        end

        vim.api.nvim_buf_delete(scratch, { force = true })
    end

    -- Helper: wait for an LSP client to attach to the current buffer.
    local function wait_for_lsp(name, filetype)
        local buf = vim.api.nvim_get_current_buf()
        if filetype then vim.bo[buf].filetype = filetype end
        local attached = vim.wait(
            15000,
            function() return #vim.lsp.get_clients({ bufnr = buf, name = name }) > 0 end,
            100
        )
        if attached then
            table.insert(results, name .. "=attached")
        else
            table.insert(failures, name .. " did not attach")
        end
        return attached
    end

    -- 1. Lua: LSP attach + StyLua formatter
    local fixtures = vim.fs.joinpath(vim.fn.stdpath("config"), "tests", "fixtures")
    vim.cmd.edit(vim.fs.joinpath(fixtures, "sample.lua"))
    assert(vim.fn.executable("stylua") == 1, "stylua missing")
    wait_for_lsp("lua_ls", "lua")
    test_formatter("lua", { "local   value={a=1,b=2}" }, "local value =", "stylua")

    -- 2. Python: formatter (isort + black)
    vim.cmd.edit(vim.fs.joinpath(fixtures, "sample.py"))
    wait_for_lsp("pyright", "python")
    test_formatter(
        "python",
        { "import requests", "import os", "x={1:2}" },
        "import os",
        "isort+black",
        { "isort", "black" }
    )

    -- 2b. Go: goimports + gofmt (Mason goimports + native toolchain gofmt)
    test_formatter(
        "go",
        { "package main", 'import "fmt"', 'func main(){fmt.Println("x")}' },
        "func main() {",
        "goimports+gofmt",
        { "goimports", "gofmt" }
    )

    -- 2c. Rust: rustfmt (native toolchain)
    test_formatter("rust", { 'fn main(){let x=1;println!("{}",x);}' }, "fn main() {", "rustfmt")

    -- 3. C++: clangd attach + Google-fallback formatter
    vim.cmd.edit(vim.fs.joinpath(fixtures, "sample.cpp"))
    wait_for_lsp("clangd", "cpp")
    test_formatter("cpp", { "int main(){return 0;}" }, "int main() {", "clang-format")

    -- 3b. Project .clang-format wins over the Google fallback (IndentWidth 7).
    --     The buffer must NOT be scratch (buftype=nofile): conform fabricates
    --     an unnamed_temp filename for nofile buffers, which breaks the
    --     clang-format project-config lookup.
    local project_dir = vim.fn.tempname()
    vim.fn.mkdir(project_dir, "p")
    vim.fn.writefile({ "IndentWidth: 7" }, vim.fs.joinpath(project_dir, ".clang-format"))
    local proj_cpp = vim.fs.joinpath(project_dir, "proj.cpp")
    local proj_buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_set_option_value("buflisted", false, { buf = proj_buf })
    vim.api.nvim_buf_set_name(proj_buf, proj_cpp)
    vim.api.nvim_set_current_buf(proj_buf)
    vim.bo[proj_buf].filetype = "cpp"
    vim.api.nvim_buf_set_lines(proj_buf, 0, -1, false, { "int main(){int a=0;if(a){return 1;}return 0;}" })
    local finished, format_error, did_edit = false, nil, nil
    require("conform").format({ bufnr = proj_buf, async = true, formatters = { "clang-format" } }, function(err, edited)
        format_error, did_edit, finished = err, edited, true
    end)
    assert(vim.wait(15000, function() return finished end, 50), "project clang-format callback timed out")
    if format_error then
        table.insert(failures, "project clang-format error: " .. tostring(format_error))
    elseif not did_edit then
        table.insert(failures, "project clang-format did not edit buffer")
    else
        local formatted = table.concat(vim.api.nvim_buf_get_lines(proj_buf, 0, -1, false), "\n")
        if formatted:find("\n       if (a) {", 1, true) then
            table.insert(results, "project-clang-format=ok")
        else
            table.insert(failures, "project .clang-format IndentWidth 7 not honored: " .. formatted)
        end
    end
    vim.api.nvim_buf_delete(proj_buf, { force = true })
    vim.fn.delete(project_dir, "rf")

    -- 4. Shell: shfmt with 4-space indent
    vim.cmd.edit(vim.fs.joinpath(fixtures, "sample.sh"))
    wait_for_lsp("bashls", "sh")
    test_formatter("sh", { "if true; then", "echo hi", "fi" }, "    echo", "shfmt")

    -- 5. Kotlin and Java: Mason-recommended formatters
    test_formatter("kotlin", { 'fun main(){println("hello")}' }, "fun main()", "ktlint")
    test_formatter(
        "java",
        { "class Main{public static void main(String[]args){}}" },
        "class Main",
        "google-java-format"
    )

    -- 6. TOML: taplo
    test_formatter("toml", { "[section]", 'key="value"' }, 'key = "value"', "taplo")

    -- 7. JavaScript: prettierd (daemon-based; covered only in bootstrapped CI)
    test_formatter("javascript", { "const x={a:1}" }, "const x = {", "prettierd")

    -- 8. Full inventory verification: every configured LSP server must map to
    --    an installed Mason package; every formatter package must be installed
    --    with a resolvable executable. Attach-level checks stay representative.
    local tools = require("config.tools")
    local registry = require("mason-registry")
    local installed = {}
    for _, name in ipairs(registry.get_installed_package_names()) do
        installed[name] = true
    end
    local mappings = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
    for _, server in ipairs(tools.lsp_servers) do
        local package_name = mappings[server]
        if not package_name then
            table.insert(failures, server .. ": no mason-lspconfig mapping")
        elseif not installed[package_name] then
            table.insert(failures, server .. ": package " .. package_name .. " not installed")
        else
            table.insert(results, server .. "=installed")
        end
    end
    for _, tool in ipairs(tools.mason_formatters) do
        if not installed[tool] then
            table.insert(failures, tool .. ": Mason package not installed")
        elseif vim.fn.executable(tool) ~= 1 then
            table.insert(failures, tool .. ": installed but not executable")
        else
            table.insert(results, tool .. "=executable")
        end
    end
    for _, tool in ipairs({ "gofmt", "rustfmt" }) do
        if vim.fn.executable(tool) ~= 1 then
            table.insert(failures, tool .. ": native toolchain formatter not executable")
        else
            table.insert(results, tool .. "=executable")
        end
    end

    -- 9. Coverage guard: every formatter configured in conform must be
    --    exercised by the runtime checks above.
    local configured = {}
    for _, info in ipairs(require("conform").list_all_formatters()) do
        configured[info.name] = true
    end
    for name in pairs(configured) do
        if not tested_formatters[name] then table.insert(failures, "formatter coverage gap: " .. name) end
    end

    if #failures > 0 then error(table.concat(failures, "\n")) end

    return results
end

local ok, results = xpcall(verify_runtime, debug.traceback)
if not ok then
    io.stderr:write("FIRST_BOOT_RUNTIME_FAILED\n" .. tostring(results) .. "\n")
    io.stderr:flush()
    vim.cmd("cquit 1")
    return
end

print("FIRST_BOOT_RUNTIME_OK " .. table.concat(results, " "))
vim.cmd("qall!")
