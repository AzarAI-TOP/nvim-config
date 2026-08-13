-- ~/.config/nvim/lua/plugins/mini-clue.lua
-- Key discovery (mini.clue, via vim.pack)
--
-- Shows available keybindings in a floating window when a prefix key is
-- pressed. Configured for all <leader> prefix groups used in this config.
--
-- The copy-to-host mappings <leader>y / <leader>Y are registered in
-- config/keymaps.lua only on remote hosts (WSL/SSH), so they are advertised
-- as clues only for remote platforms. build_triggers(platform) is exported
-- so tests can inject local/remote platform states.

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.clue" },
})

local miniclue = require("mini.clue")

local M = {}

---Build the mini.clue triggers array for a given platform.
---@param platform table  Platform table with an is_remote boolean
---                       (see config/platform.lua; tests inject a stub).
---@return table  mini.clue triggers array.
function M.build_triggers(platform)
    local triggers = {
        -- Leader key groups
        { mode = "n", keys = "<leader>b", desc = "+buffer" },
        { mode = "n", keys = "<leader>c", desc = "+config" },
        { mode = "n", keys = "<leader>l", desc = "+language" },
        { mode = "n", keys = "<leader>f", desc = "+find" },
        { mode = "n", keys = "<leader>w", desc = "+window" },
        { mode = "n", keys = "<leader>t", desc = "+toggle" },
        { mode = "n", keys = "<leader>p", desc = "+package" },
        { mode = "n", keys = "<leader>s", desc = "+split" },
        { mode = "n", keys = "<leader>e", desc = "File explorer" },
        { mode = "n", keys = "<leader>nh", desc = "Clear search highlight" },
        { mode = "n", keys = "<leader>q", desc = "Quit" },
        { mode = "n", keys = "<leader>Q", desc = "Quit all" },
    }

    -- Matches the remote-only registration in config/keymaps.lua.
    if platform.is_remote then
        table.insert(triggers, { mode = "n", keys = "<leader>y", desc = "Copy to host clipboard" })
        table.insert(triggers, { mode = "n", keys = "<leader>Y", desc = "Copy line to host clipboard" })
    end

    return triggers
end

miniclue.setup({
    triggers = M.build_triggers(require("config.platform")),

    clues = {
        miniclue.gen_clues.builtin_completion(),
    },

    window = {
        delay = 300,
        config = {
            border = "rounded",
        },
    },
})

return M
