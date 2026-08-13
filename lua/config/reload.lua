-- 核心配置层的真正热重载（options / keymaps / autocmds / Neovide 设置 /
-- pack 命令 / LSP 配置）。
--
-- 插件的 setup 刻意不重跑：插件文件改动（setup 选项、treesitter 解析器、
-- 配色风格）仍需重启。reload 恢复的内容：
--   1. 已登记的按键（经 config.util 登记表删除后重建）
--   2. 本配置拥有的用户命令（:PackUpdate / :PackList）
--   3. 全部 config.* 模块（清空 package.loaded 后按启动顺序重新 require）；
--      augroup 均带 clear=true，重跑即重建；mini.clue 会重新 setup 刷新触发项

local M = {}

local CORE = {
    "config.options",
    "config.keymaps",
    "config.autocmds",
    "config.neovide",
    "config.pack",
    "config.lsp",
}

-- 可安全重跑的插件模块（用于刷新依赖上述配置的状态）。
-- mini.clue 的触发项依赖已注册的按键。
local RERUN_PLUGIN = { "plugins.mini" }

local OWNED_COMMANDS = { "PackUpdate", "PackList" }

local function clear_owned_modules()
    for name in pairs(package.loaded) do
        -- config.util（按键登记表）与 config.reload（本模块）必须保留。
        if name ~= "config.util" and name ~= "config.reload" then
            if name:match("^config%.") then package.loaded[name] = nil end
        end
    end
    -- RERUN_PLUGIN 也要清掉，否则 re-require 命中缓存，setup 不会真正重跑。
    for _, name in ipairs(RERUN_PLUGIN) do
        package.loaded[name] = nil
    end
end

---重载核心配置层。可反复调用；单模块报错不影响其余模块。
function M.reload()
    require("config.util").delete_all_keymaps()
    for _, cmd in ipairs(OWNED_COMMANDS) do
        pcall(vim.api.nvim_del_user_command, cmd)
    end

    clear_owned_modules()

    for _, name in ipairs(CORE) do
        local ok, err = pcall(require, name)
        if not ok then
            vim.notify("重载失败 " .. name .. ": " .. tostring(err), vim.log.levels.ERROR, { title = "reload" })
        end
    end
    for _, name in ipairs(RERUN_PLUGIN) do
        pcall(require, name)
    end

    vim.notify("配置已重新加载（插件 setup 未重跑）", vim.log.levels.INFO)
end

return M
