-- Toggleable terminals (akinsho/toggleterm.nvim) — lazy loaded: the first
-- toggle keypress pulls the plugin in through the toggleterm.terminal
-- preload stub.
--
-- Entry points live in config/keymaps.lua via the factories exported below;
-- each binding owns a fixed terminal id, so toggling always reopens the same
-- terminal (Terminal:new returns the existing terminal for a taken id, which
-- also keeps the bindings working after a :ConfigReload). The default <C-\>
-- open mapping is disabled so the key surface stays exactly the one defined
-- in keymaps.lua; terminal-mode escape remains <C-\><C-n> and <Esc><Esc>.

require("config.lazy").defer("toggleterm", {
    mods = { "toggleterm.terminal" },
    loader = function()
        vim.pack.add({
            { src = "https://github.com/akinsho/toggleterm.nvim" },
        })

        require("toggleterm").setup({
            -- No default <C-\> open mapping: every toggle goes through the
            -- keymaps in config/keymaps.lua.
            open_mapping = false,
            -- Split size must be a function: a single number applies to every
            -- direction, which would cap vertical splits at 15 columns. Horizontal
            -- terminals open 15 rows; vertical ones 40% of the editor width. Floats
            -- size themselves and never consult this option.
            size = function(term)
                if term.direction == "vertical" then return math.floor(vim.o.columns * 0.4) end
                return 15
            end,
            -- Floating terminal border matches the config's rounded border language.
            float_opts = { border = "rounded" },
        })
    end,
})

local M = {}

---Toggle closure for a fixed terminal id (the keymaps bind one per direction).
---@param id integer
---@param direction "horizontal"|"vertical"|"float"
---@param cmd? string command to run instead of the configured shell
function M.toggle(id, direction, cmd)
    return function()
        require("toggleterm.terminal").Terminal:new({ id = id, direction = direction, cmd = cmd }):toggle()
    end
end

---The floating toggle (id 5): one closure shared by the <leader>tf / <F2>
---bindings and the terminal-mode fallback below, so they cannot drift apart.
M.toggle_float = M.toggle(5, "float")

---Terminal-mode toggle: the terminal under the cursor when identify() finds a
---fixed-id toggleterm (it reads the id from the buffer-name tag the plugin
---writes at spawn time); untagged :terminal buffers fall back to the float.
function M.toggle_current()
    local _, term = require("toggleterm.terminal").identify()
    if term then
        term:toggle()
    else
        M.toggle_float()
    end
end

return M
