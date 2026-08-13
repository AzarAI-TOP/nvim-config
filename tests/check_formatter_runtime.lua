-- Real prettierd runtime probes. Runs only in a bootstrapped environment where
-- Mason has installed prettierd (Linux first-boot CI job and local bootstrap
-- verification) — NOT part of the ordinary offline suite. Invoke through
-- scripts/run-formatter-runtime-probe.sh (see README "Verification").
--
-- Proves three observable behaviors:
--   1. prettierd formats a TypeScript buffer with Prettier's built-in defaults
--      when the project has no Prettier configuration (require_cwd=false);
--   2. prettierd honors a project .prettierrc (singleQuote: true) when one
--      exists;
--   3. a formatter whose command is unavailable is reported unavailable and
--      never edits the buffer — a valid-looking config table is not accepted.
--
-- Test-only injection: with NVIM_FORMATTER_RUNTIME_MUTATION=1 the prettierd
-- command is replaced in memory (nothing on disk changes) by a nonexistent
-- binary. Every positive probe must then fail, proving the probe is not
-- vacuously green. CI and local RED verification use this flag.

local conform = require("conform")

if vim.env.NVIM_FORMATTER_RUNTIME_MUTATION == "1" then
    local prettierd = conform.formatters["prettierd"]
    assert(prettierd, "prettierd formatter config not registered")
    prettierd.command = "definitely-not-a-real-prettierd-binary-xyz"
end

local original_buf = vim.api.nvim_get_current_buf()
local created_bufs = {}
local temp_roots = {}
local saved_bogus_formatter = conform.formatters["prettierd_bogus"]

-- Buffers must NOT be scratch (buftype=nofile): conform's build_context then
-- ignores the buffer name and fabricates "unnamed_temp" in getcwd(), so the
-- project directory and its .prettierrc would never be seen. Unlisted regular
-- buffers keep the name and let conform resolve cwd/config from the file.
local function scratch_buf(file, content, filetype)
    local buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_name(buf, file)
    vim.bo[buf].filetype = filetype or "typescript"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    table.insert(created_bufs, buf)
    return buf
end

local function write_file(path, content)
    local f = assert(io.open(path, "w"))
    f:write(content)
    f:close()
end

local function format_with(buf, formatters)
    local finished, format_error, did_edit = false, nil, nil
    conform.format({ bufnr = buf, async = true, formatters = formatters, lsp_format = "never" }, function(err, edited)
        format_error, did_edit, finished = err, edited, true
    end)
    assert(
        vim.wait(20000, function() return finished end, 50),
        "formatter callback timed out (async job never completed)"
    )
    return format_error, did_edit
end

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

local function probe_project(name, prettier_config, source, expected)
    local root = vim.fn.tempname() .. "-" .. name
    vim.fn.mkdir(root, "p")
    table.insert(temp_roots, root)
    local file = root .. "/sample.ts"
    write_file(file, source)
    if prettier_config then write_file(root .. "/.prettierrc", prettier_config) end

    local buf = scratch_buf(file, source, "typescript")

    -- Formatter info must report availability and resolve to prettierd.
    local info = conform.get_formatter_info("prettierd", buf)
    check(info.available == true, name .. ": prettierd must be available (got: " .. tostring(info.available_msg) .. ")")
    check(info.name == "prettierd", name .. ": formatter name must resolve to prettierd")

    local format_error, did_edit = format_with(buf, { "prettierd" })
    check(format_error == nil, name .. ": format must finish without error (got: " .. tostring(format_error) .. ")")
    check(did_edit == true, name .. ": prettierd must edit the buffer (did_edit=" .. tostring(did_edit) .. ")")

    local output = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    check(output:find(expected, 1, true) ~= nil, name .. ": output must contain '" .. expected .. "', got: " .. output)
end

local function run_probes()
    -- Project A: no Prettier configuration -> Prettier built-in defaults
    -- (semi=true, singleQuote=false).
    probe_project("no-config", nil, 'const s="hi"', '"hi";')

    -- Project B: .prettierrc with singleQuote -> project option must win.
    probe_project("with-config", '{"singleQuote": true}', 'const s="hi"', "'hi';")

    -- Negative: an unavailable formatter command must be reported and never edit.
    local bogus_root = vim.fn.tempname() .. "-bogus"
    vim.fn.mkdir(bogus_root, "p")
    table.insert(temp_roots, bogus_root)
    local bogus_file = bogus_root .. "/sample.ts"
    local bogus_source = 'const s="hi"'
    write_file(bogus_file, bogus_source)
    local bogus_buf = scratch_buf(bogus_file, bogus_source, "typescript")
    conform.formatters["prettierd_bogus"] = { command = "definitely-not-a-real-prettierd-binary-xyz" }
    local bogus_info = conform.get_formatter_info("prettierd_bogus", bogus_buf)
    check(bogus_info.available == false, "unavailable command must be reported as unavailable")
    check(
        bogus_info.available_msg and bogus_info.available_msg:find("not found", 1, true) ~= nil,
        "unavailable command message must say the command was not found (got: "
            .. tostring(bogus_info.available_msg)
            .. ")"
    )
    local bogus_error, bogus_did_edit = format_with(bogus_buf, { "prettierd_bogus" })
    -- Conform drops unavailable formatters before running: the format call
    -- completes with an error message and never edits the buffer.
    check(
        type(bogus_error) == "string" and bogus_error:find("No formatters available", 1, true) ~= nil,
        "unavailable command must be surfaced as a format error (got: " .. tostring(bogus_error) .. ")"
    )
    check(
        not bogus_did_edit,
        "unavailable command must not edit the buffer (did_edit=" .. tostring(bogus_did_edit) .. ")"
    )
    local bogus_output = table.concat(vim.api.nvim_buf_get_lines(bogus_buf, 0, -1, false), "\n")
    check(
        bogus_output == bogus_source,
        "unavailable command must leave buffer content untouched (got: " .. bogus_output .. ")"
    )
end

local probes_ok, probes_err = xpcall(run_probes, debug.traceback)

-- Unconditional cleanup, even when a probe raised or a check failed. prettierd
-- keeps a daemon whose cwd pins each temp root, so daemons must be stopped
-- before the roots can be deleted; the current buffer and the conform override
-- are restored afterwards.
local function cleanup()
    conform.formatters["prettierd_bogus"] = saved_bogus_formatter
    local stop_cmd = (vim.fn.executable("prettierd.cmd") == 1 and "prettierd.cmd") or "prettierd"
    if vim.fn.executable(stop_cmd) == 1 then
        local done = false
        vim.system({ stop_cmd, "stop" }, nil, vim.schedule_wrap(function() done = true end))
        vim.wait(10000, function() return done end, 50)
    end
    for _, buf in ipairs(created_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
    end
    for _, root in ipairs(temp_roots) do
        pcall(vim.fn.delete, root, "rf")
    end
    if vim.api.nvim_buf_is_valid(original_buf) then pcall(vim.api.nvim_set_current_buf, original_buf) end
end
local cleanup_ok, cleanup_err = pcall(cleanup)

if not probes_ok or #failures > 0 or not cleanup_ok then
    io.stderr:write("FORMATTER_RUNTIME_CHECK_FAILED\n")
    if not probes_ok then io.stderr:write("probe raised: " .. tostring(probes_err) .. "\n") end
    if #failures > 0 then io.stderr:write("- " .. table.concat(failures, "\n- ") .. "\n") end
    if not cleanup_ok then io.stderr:write("cleanup failed: " .. tostring(cleanup_err) .. "\n") end
    io.stderr:flush()
    vim.cmd("cquit 1")
    return
end

print("FORMATTER_RUNTIME_CHECK_OK no-config with-config unavailable")
vim.cmd("qall!")
