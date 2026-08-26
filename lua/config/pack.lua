-- vim.pack-based plugin update / list commands (no third-party plugin manager).
-- The PackList row builder lives in config.util (pack_rows); this file only
-- registers the user commands, so reload can delete and rebuild them.

-- Follows the official vim.pack update flow (:help pack-update):
-- downloads updates and opens a confirmation buffer in a separate tabpage —
-- :write applies the changes, :quit discards them, optionally :restart loads
-- the updated plugin code.
vim.api.nvim_create_user_command("PackUpdate", function()
    local ok, err = pcall(vim.pack.update)
    if not ok then
        vim.notify("Plugin update failed: " .. tostring(err), vim.log.levels.ERROR, { title = "PackUpdate" })
    end
end, { desc = "Update vim.pack plugins (opens review buffer)", nargs = 0 })

vim.api.nvim_create_user_command("PackList", function()
    local ok, fzf = pcall(require, "fzf-lua")
    if not ok then
        vim.notify("fzf-lua unavailable", vim.log.levels.ERROR)
        return
    end
    fzf.fzf_exec(require("config.util").pack_rows(), { prompt = "plugins> " })
end, { desc = "List vim.pack plugins", nargs = 0 })
