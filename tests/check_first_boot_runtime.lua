-- 完整引导环境的集成检查。
-- 在一次性 XDG 环境中 Mason 安装完成后运行，
-- 用真实夹具内容测试多个 LSP 服务器与格式化器。

local function verify_runtime()
    if vim.env.NVIM_FORCE_RUNTIME_TEST_FAILURE == "1" then error("强制的运行时测试失败") end

    local results = {}
    local failures = {}
    local tested_formatters = {}

    -- 辅助函数：在临时缓冲区上测试一个格式化器。
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
        assert(vim.wait(15000, function() return finished end, 50), formatter_name .. " 回调超时")

        if format_error then
            table.insert(failures, formatter_name .. " 出错：" .. tostring(format_error))
        elseif not did_edit then
            table.insert(failures, formatter_name .. " 未编辑缓冲区")
        else
            local formatted = table.concat(vim.api.nvim_buf_get_lines(scratch, 0, -1, false), "\n")
            if formatted:find(expected_substring, 1, true) then
                table.insert(results, formatter_name .. "=ok")
            else
                table.insert(failures, formatter_name .. " 输出异常：" .. formatted)
            end
        end

        vim.api.nvim_buf_delete(scratch, { force = true })
    end

    -- 辅助函数：等待 LSP 客户端附着到当前缓冲区。
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
            table.insert(failures, name .. " 未附着")
        end
        return attached
    end

    -- 1. Lua：LSP 附着 + StyLua 格式化器
    local fixtures = vim.fs.joinpath(vim.fn.stdpath("config"), "tests", "fixtures")
    vim.cmd.edit(vim.fs.joinpath(fixtures, "sample.lua"))
    assert(vim.fn.executable("stylua") == 1, "stylua 缺失")
    wait_for_lsp("lua_ls", "lua")
    test_formatter("lua", { "local   value={a=1,b=2}" }, "local value =", "stylua")

    -- 2. Python：格式化器（isort + black）
    vim.cmd.edit(vim.fs.joinpath(fixtures, "sample.py"))
    wait_for_lsp("pyright", "python")
    test_formatter(
        "python",
        { "import requests", "import os", "x={1:2}" },
        "import os",
        "isort+black",
        { "isort", "black" }
    )

    -- 2b. Go：goimports + gofmt（Mason goimports + 原生工具链 gofmt）
    test_formatter(
        "go",
        { "package main", 'import "fmt"', 'func main(){fmt.Println("x")}' },
        "func main() {",
        "goimports+gofmt",
        { "goimports", "gofmt" }
    )

    -- 2c. Rust：rustfmt（原生工具链）
    test_formatter("rust", { 'fn main(){let x=1;println!("{}",x);}' }, "fn main() {", "rustfmt")

    -- 3. C++：clangd 附着 + Google 兜底格式化器
    vim.cmd.edit(vim.fs.joinpath(fixtures, "sample.cpp"))
    wait_for_lsp("clangd", "cpp")
    test_formatter("cpp", { "int main(){return 0;}" }, "int main() {", "clang-format")

    -- 3b. 项目 .clang-format 优先于 Google 兜底（IndentWidth 7）。
    --     缓冲区必须不是 scratch（buftype=nofile）：conform 会为 nofile
    --     缓冲区伪造 unnamed_temp 文件名，破坏 clang-format 的项目配置查找。
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
    assert(vim.wait(15000, function() return finished end, 50), "项目 clang-format 回调超时")
    if format_error then
        table.insert(failures, "项目 clang-format 出错：" .. tostring(format_error))
    elseif not did_edit then
        table.insert(failures, "项目 clang-format 未编辑缓冲区")
    else
        local formatted = table.concat(vim.api.nvim_buf_get_lines(proj_buf, 0, -1, false), "\n")
        if formatted:find("\n       if (a) {", 1, true) then
            table.insert(results, "project-clang-format=ok")
        else
            table.insert(failures, "项目 .clang-format IndentWidth 7 未生效：" .. formatted)
        end
    end
    vim.api.nvim_buf_delete(proj_buf, { force = true })
    vim.fn.delete(project_dir, "rf")

    -- 4. Shell：shfmt 4 空格缩进
    vim.cmd.edit(vim.fs.joinpath(fixtures, "sample.sh"))
    wait_for_lsp("bashls", "sh")
    test_formatter("sh", { "if true; then", "echo hi", "fi" }, "    echo", "shfmt")

    -- 5. Kotlin 与 Java：Mason 推荐的格式化器
    test_formatter("kotlin", { 'fun main(){println("hello")}' }, "fun main()", "ktlint")
    test_formatter(
        "java",
        { "class Main{public static void main(String[]args){}}" },
        "class Main",
        "google-java-format"
    )

    -- 6. TOML：taplo
    test_formatter("toml", { "[section]", 'key="value"' }, 'key = "value"', "taplo")

    -- 7. JavaScript：prettierd（守护进程式；仅在引导后的 CI 覆盖）
    test_formatter("javascript", { "const x={a:1}" }, "const x = {", "prettierd")

    -- 8. 完整清单校验：每个配置的 LSP 服务器必须映射到已安装的 Mason 包；
    --    每个格式化器包必须已安装且可执行。附着级检查保持代表性。
    local util = require("config.util")
    local registry = require("mason-registry")
    local installed = {}
    for _, name in ipairs(registry.get_installed_package_names()) do
        installed[name] = true
    end
    local mappings = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
    for _, server in ipairs(util.lsp_servers) do
        local package_name = mappings[server]
        if not package_name then
            table.insert(failures, server .. "：没有 mason-lspconfig 映射")
        elseif not installed[package_name] then
            table.insert(failures, server .. "：包 " .. package_name .. " 未安装")
        else
            table.insert(results, server .. "=installed")
        end
    end
    for _, tool in ipairs(util.mason_formatters) do
        if not installed[tool] then
            table.insert(failures, tool .. "：Mason 包未安装")
        elseif vim.fn.executable(tool) ~= 1 then
            table.insert(failures, tool .. "：已安装但不可执行")
        else
            table.insert(results, tool .. "=executable")
        end
    end
    for _, tool in ipairs({ "gofmt", "rustfmt" }) do
        if vim.fn.executable(tool) ~= 1 then
            table.insert(failures, tool .. "：原生工具链格式化器不可执行")
        else
            table.insert(results, tool .. "=executable")
        end
    end

    -- 9. 覆盖守卫：conform 配置的每个格式化器都必须被上述运行时检查执行过。
    local configured = {}
    for _, info in ipairs(require("conform").list_all_formatters()) do
        configured[info.name] = true
    end
    for name in pairs(configured) do
        if not tested_formatters[name] then table.insert(failures, "格式化器覆盖缺口：" .. name) end
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
