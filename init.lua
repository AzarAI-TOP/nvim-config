-- ~/.config/nvim/init.lua
-- Minimal Neovim configuration

-- Core editor modules
require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.neovide") -- Neovide GUI settings (no-op outside Neovide)

-- Plugins (auto-loaded from lua/plugins/)
require("plugins")

-- Language server protocol
require("config.lsp")
