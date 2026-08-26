-- Plugin loader. Every file under lua/plugins/ declares its own vim.pack.add
-- and setup; adding a plugin means adding a file. A few infrastructure plugins
-- load first by priority, the rest load alphabetically, keeping the order
-- deterministic.

local priority = {
    "mini", -- all mini.* plugins (icons, keymap hints, and other infrastructure)
    "mason", -- package manager (also defines :MasonTools* early)
    "tokyonight", -- colorscheme (applied immediately to avoid flash)
}

local dir = vim.fn.stdpath("config") .. "/lua/plugins"

local loaded = {}
for _, name in ipairs(priority) do
    require("plugins." .. name)
    loaded[name] = true
end

local rest = {}
for name, ftype in vim.fs.dir(dir) do
    if ftype == "file" and name:match("%.lua$") and name ~= "init.lua" then
        local module_name = name:gsub("%.lua$", "")
        if not loaded[module_name] then table.insert(rest, module_name) end
    end
end
table.sort(rest)
for _, name in ipairs(rest) do
    require("plugins." .. name)
end
