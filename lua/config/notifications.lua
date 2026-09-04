-- Notification history as an fzf picker (<leader>fn in config/keymaps.lua):
-- fuzzy search over one-line entries (colored level + timestamp + collapsed
-- message), preview pane shows the full message. opts.preview is the fzf-lua
-- pattern also used by registers.

local M = {}

function M.pick()
    local entries = require("mini.notify").get_all()
    if #entries == 0 then
        vim.notify("No notifications yet", vim.log.levels.INFO)
        return
    end
    -- Newest first.
    table.sort(entries, function(a, b) return a.ts_update > b.ts_update end)

    local ansi = require("fzf-lua.utils").ansi_codes
    local level_color = {
        ERROR = ansi.red,
        WARN = ansi.yellow,
        INFO = ansi.green,
        DEBUG = ansi.cyan,
        TRACE = ansi.magenta,
    }

    local items, previews = {}, {}
    for i, n in ipairs(entries) do
        -- Millisecond precision keeps display lines unique: the preview
        -- matches by line, and same-second identical collapses would
        -- otherwise preview the wrong full message.
        local ms = string.format(".%03d", math.floor(n.ts_update * 1000) % 1000)
        local ts = vim.fn.strftime("%H:%M:%S", math.floor(n.ts_update)) .. ms
        local color = level_color[n.level] or ansi.white
        items[i] = color(string.format("[%s]", n.level)) .. " " .. ts .. " " .. n.msg:gsub("[\r\n]", " ")
        previews[i] = string.format("[%s] %s\n\n%s", n.level, ts, n.msg)
    end

    require("fzf-lua").fzf_exec(items, {
        prompt = "Notifications> ",
        preview = function(args)
            local sel = args[1]
            for i, item in ipairs(items) do
                if item == sel then return previews[i] end
            end
            return sel
        end,
    })
end

return M
