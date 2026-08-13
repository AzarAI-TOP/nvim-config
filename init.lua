-- 入口：先加载核心编辑器模块，再加载插件，最后接入 LSP。

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.neovide") -- Neovide GUI 设置（Neovide 之外为空操作）
require("config.pack") -- :PackUpdate / :PackList 用户命令

-- 插件（自动加载 lua/plugins/ 下的全部文件）
require("plugins")

-- 语言服务器协议
require("config.lsp")
