-- vim.pack-based plugin update / list commands (no third-party plugin manager).
--
-- Follows the official vim.pack update flow (:help pack-update): downloads
-- updates and opens a confirmation buffer in a separate tabpage — :write
-- applies the changes, :quit discards them, optionally :restart loads the
-- updated plugin code.
vim.api.nvim_create_user_command(
    "PackUpdate",
    function() vim.pack.update() end,
    { desc = "Update vim.pack plugins (opens review buffer)", nargs = 0 }
)

-- Strips protocol/host from a plugin source, keeping "author/repo"
-- (e.g. "https://github.com/folke/noice.nvim" -> "folke/noice.nvim").
local function short_src(src)
    local path = src:match("^%a+://[^/]+/(.+)$") or src:match("^git@[^:]+:(.+)$") or src
    return path:gsub("%.git$", "")
end

---One row per plugin, sorted by name: "name  author/repo", second column aligned.
local function pack_rows()
    local rows = {}
    local width = 0
    for _, plugin in ipairs(vim.pack.get()) do
        local spec = plugin.spec or {}
        local name = spec.name or "?"
        width = math.max(width, #name)
        table.insert(rows, { name = name, src = short_src(spec.src or "") })
    end
    for i, row in ipairs(rows) do
        rows[i] = (string.format("%-" .. width .. "s  %s", row.name, row.src)):gsub("%s+$", "")
    end
    table.sort(rows)
    return rows
end

vim.api.nvim_create_user_command(
    "PackList",
    function() require("fzf-lua").fzf_exec(pack_rows(), { prompt = "plugins> " }) end,
    { desc = "List vim.pack plugins", nargs = 0 }
)
