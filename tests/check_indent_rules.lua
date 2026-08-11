-- Test per-filetype indentation rules defined in config/autocmds.lua.
-- Verifies that each filetype group gets the expected tabstop, shiftwidth,
-- and expandtab values by opening a scratch buffer and setting the filetype.

local failures = {}

local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

-- Expected indent settings: [tabstop, shiftwidth, expandtab]
-- Must match the indent_groups table in autocmds.lua.
local expected = {
    -- 2 spaces
    ["lua"] = { 2, 2, true },
    ["vim"] = { 2, 2, true },
    ["javascript"] = { 2, 2, true },
    ["typescript"] = { 2, 2, true },
    ["html"] = { 2, 2, true },
    ["css"] = { 2, 2, true },
    ["json"] = { 2, 2, true },
    ["yaml"] = { 2, 2, true },
    ["markdown"] = { 2, 2, true },
    ["sh"] = { 2, 2, true },
    ["toml"] = { 2, 2, true },
    -- 4 spaces
    ["python"] = { 4, 4, true },
    ["rust"] = { 4, 4, true },
    ["c"] = { 4, 4, true },
    ["cpp"] = { 4, 4, true },
    ["java"] = { 4, 4, true },
    ["kotlin"] = { 4, 4, true },
    -- Tabs
    ["go"] = { 4, 4, false },
    ["make"] = { 4, 4, false },
}

for ft, exp in pairs(expected) do
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = ft
    -- Trigger FileType autocommands
    vim.api.nvim_exec_autocmds("FileType", { buffer = buf })

    local ts = vim.bo[buf].tabstop
    local sw = vim.bo[buf].shiftwidth
    local et = vim.bo[buf].expandtab

    check(ts == exp[1], ft .. ": tabstop=" .. ts .. " expected " .. exp[1])
    check(sw == exp[2], ft .. ": shiftwidth=" .. sw .. " expected " .. exp[2])
    check(et == exp[3], ft .. ": expandtab=" .. tostring(et) .. " expected " .. tostring(exp[3]))

    vim.api.nvim_buf_delete(buf, { force = true })
end

if #failures > 0 then
    io.stderr:write("INDENT_RULES_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write(("INDENT_RULES_CHECK_OK filetypes=%d\n"):format(vim.tbl_count(expected)))
if not vim.g.config_test_runner then vim.cmd("qa") end
