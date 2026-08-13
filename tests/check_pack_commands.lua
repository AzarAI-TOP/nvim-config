-- Pack command checks: :PackUpdate / :PackList exist and entries() is a pure,
-- testable row builder over vim.pack.get().

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

check(vim.fn.exists(":PackUpdate") == 2, ":PackUpdate must be defined")
check(vim.fn.exists(":PackList") == 2, ":PackList must be defined")

-- entries(): pure builder, vim.pack.get() injectable at call time.
local pack = require("config.pack")
local orig_get = vim.pack.get
vim.pack.get = function()
    return {
        { spec = { name = "b.nvim", src = "https://example.com/b" }, rev = "aaa" },
        { spec = { name = "a.nvim", src = "https://example.com/a" }, rev = "bbb" },
    }
end
local rows = pack.entries()
vim.pack.get = orig_get

check(type(rows) == "table" and #rows == 2, "entries must return one row per plugin")
if type(rows) == "table" and #rows == 2 then
    check(rows[1]:find("a.nvim", 1, true) ~= nil, "entries must be sorted by plugin name")
    check(rows[1]:find("https://example.com/a", 1, true) ~= nil, "row must contain src")
    check(rows[1]:find("bbb", 1, true) ~= nil, "row must contain rev")
end

if #failures > 0 then
    io.stderr:write("PACK_COMMANDS_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("PACK_COMMANDS_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
