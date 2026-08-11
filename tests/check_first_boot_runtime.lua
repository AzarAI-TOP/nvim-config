-- Integration check for a fully bootstrapped environment.
-- Tests multiple LSP servers and formatters against real fixture content.
-- Run after Mason installation in a disposable XDG environment.

local function verify_runtime()
    if vim.env.NVIM_FORCE_RUNTIME_TEST_FAILURE == "1" then error("forced runtime test failure") end

    local results = {}
    local failures = {}

    -- Helper: test a formatter on a scratch buffer.
    local function test_formatter(ft, bad_content, expected_substring, formatter_name)
        local scratch = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(scratch)
        vim.bo[scratch].filetype = ft
        vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { bad_content })

        local finished, format_error, did_edit = false, nil, nil
        require("conform").format({ bufnr = scratch, async = true }, function(err, edited)
            format_error, did_edit, finished = err, edited, true
        end)
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
    assert(vim.fn.executable("stylua") == 1, "stylua missing")
    wait_for_lsp("lua_ls", "lua")
    test_formatter("lua", "local   value={a=1,b=2}", "local value =", "stylua")

    -- 2. Python: formatter (isort + black)
    test_formatter("python", "import sys\nimport os", "import os\nimport sys", "isort+black")

    -- 3. Shell: shfmt with 4-space indent
    test_formatter("sh", "if [ $1 ];then echo hi;fi", "    echo", "shfmt")

    -- 4. TOML: taplo
    test_formatter("toml", "[section]\nkey=value", "key = value", "taplo")

    -- 5. Verify all Mason packages are installed
    local missing, unmapped = require("config.mason_verify").missing_packages()
    if #missing > 0 then table.insert(failures, "Missing Mason packages: " .. table.concat(missing, ", ")) end
    if #unmapped > 0 then table.insert(failures, "Unmapped LSP servers: " .. table.concat(unmapped, ", ")) end

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
