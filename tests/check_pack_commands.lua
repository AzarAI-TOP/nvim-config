-- pack 命令检查：:PackUpdate / :PackList 必须存在，
-- entries() 是基于 vim.pack.get() 的纯、可测试行构建器。

local failures = {}
local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

check(vim.fn.exists(":PackUpdate") == 2, ":PackUpdate 必须已定义")
check(vim.fn.exists(":PackList") == 2, ":PackList 必须已定义")

-- entries()：纯构建器，vim.pack.get() 可在调用时注入。
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

check(type(rows) == "table" and #rows == 2, "entries 必须每个插件返回一行")
if type(rows) == "table" and #rows == 2 then
    check(rows[1]:find("a.nvim", 1, true) ~= nil, "entries 必须按插件名排序")
    check(rows[1]:find("https://example.com/a", 1, true) ~= nil, "行必须包含来源")
    check(rows[1]:find("bbb", 1, true) ~= nil, "行必须包含版本")
end

if #failures > 0 then
    io.stderr:write("PACK_COMMANDS_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("PACK_COMMANDS_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
