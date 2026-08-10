local mapping = vim.fn.maparg("<leader>lf", "n", false, true)
local failures = {}
local notifications = {}

local function check(condition, message)
    if not condition then table.insert(failures, message) end
end

check(type(mapping.callback) == "function", "<leader>lf must use a Lua callback")

local original_conform = package.loaded["conform"]
local original_notify = vim.notify
vim.notify = function(message, level) table.insert(notifications, { message = message, level = level }) end

package.loaded["conform"] = {
    format = function(options, callback)
        check(options.async == true, "formatting must be asynchronous")
        check(options.timeout_ms == nil, "async formatting must not claim a timeout")
        check(type(callback) == "function", "format callback missing")
        callback(nil, true)
    end,
}

if type(mapping.callback) == "function" then mapping.callback() end
check(#notifications == 1 and notifications[1].message == "已格式化", "success notification missing")

notifications = {}
package.loaded["conform"].format = function(_, callback) callback("formatter failed", false) end
if type(mapping.callback) == "function" then mapping.callback() end
check(
    #notifications == 1 and notifications[1].level == vim.log.levels.ERROR,
    "format errors must produce an error notification"
)

notifications = {}
package.loaded["conform"].format = function(_, callback) callback(nil, false) end
if type(mapping.callback) == "function" then mapping.callback() end
check(#notifications == 1 and notifications[1].level == vim.log.levels.WARN, "no-op formatting must not report success")

package.loaded["conform"] = original_conform
vim.notify = original_notify

if #failures > 0 then
    io.stderr:write("FORMAT_KEYMAP_CHECK_FAILED:\n- " .. table.concat(failures, "\n- ") .. "\n")
    vim.cmd("cquit 1")
end

io.stdout:write("FORMAT_KEYMAP_CHECK_OK\n")
if not vim.g.config_test_runner then vim.cmd("qa") end
