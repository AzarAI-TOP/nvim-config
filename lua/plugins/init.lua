-- ~/.config/nvim/lua/plugins/init.lua
-- Plugin auto-loader
-- Requires every .lua file under lua/plugins/ except itself.
-- Each plugin file is self-contained: vim.pack.add + setup.
-- Adding or removing a plugin = adding or removing one file.

local dir = vim.fn.stdpath("config") .. "/lua/plugins"

local modules = {}
for name, ftype in vim.fs.dir(dir) do
    if ftype == "file" and name:match("%.lua$") and name ~= "init.lua" then
        table.insert(modules, (name:gsub("%.lua$", "")))
    end
end

-- Filesystem iteration order differs between NTFS and Linux filesystems.
-- Sorting makes startup deterministic on every platform.
table.sort(modules)
for _, module in ipairs(modules) do
    require("plugins." .. module)
end
