-- Entry point: load core editor modules first, then plugins, then wire up LSP.

require("config.options")
require("config.colors") -- popupmenu & per-kind highlights (noice + tokyonight moon)
require("config.keymaps")
require("config.autocmds")
require("config.neovide") -- Neovide GUI settings (no-op outside Neovide)
require("config.pack") -- :PackUpdate / :PackList user commands

-- Plugins (auto-loads every file under lua/plugins/)
require("plugins")

-- Language Server Protocol
require("config.lsp")
