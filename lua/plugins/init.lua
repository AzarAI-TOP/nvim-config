-- 插件加载器。lua/plugins/ 下每个文件声明自己的 vim.pack.add 和 setup；
-- 加一个插件就是加一个文件。少量基础设施插件按优先级先加载，
-- 其余按字母序加载，保证跨平台顺序确定。

local priority = {
    "mini", -- 全部 mini.* 插件（图标、键位提示等基础设施）
    "mason", -- 包管理器（同时尽早定义 :MasonTools*）
    "tokyonight", -- 配色方案（立即应用，避免闪屏）
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
