-- Buffer management (bento.nvim, v2 API) — lazy loaded on its sole trigger:
-- the `;` key. The stub mapping loads the plugin (whose API registrations
-- below install the real `;` mapping) and replays the keypress, so the first
-- `;` opens bento exactly like every later one.

require("config.lazy").defer("bento", {
    keys = { { mode = "n", lhs = ";" } },
    loader = function()
        vim.pack.add({
            -- v2 lives on feat/v2: main is still v1 (the announced July 2026
            -- merge has not happened; the repo has been dormant since
            -- 2026-05). The lock file pins the exact rev, so branch drift only
            -- enters through a deliberate :PackUpdate.
            { src = "https://github.com/serhez/bento.nvim", version = "feat/v2" },
        })

        require("bento").setup({
            ui = {
                mode = "floating",
                floating = {
                    position = "middle-right",
                    border = "rounded",
                },
            },
        })

        -- v2 registers no keys or actions by default; rebuild the v1 surface.
        local api = require("bento.api")
        -- Same key for both: menu closed -> jump to the last buffer, menu
        -- open -> expand (upstream's recipe for the v1 main_keymap).
        api.register_expand_key(";")
        api.register_last_buffer_key(";")
        api.register_collapse_key("<Esc>")
        api.register_prev_page_key("[")
        api.register_next_page_key("]")
        api.register_action("open", { key = "<CR>", action = api.actions.open })
        api.register_action("delete", { key = "<BS>", action = api.actions.delete })
        api.register_action("vsplit", { key = "|", action = api.actions.vsplit })
        api.register_action("split", { key = "_", action = api.actions.split })
        api.register_action("lock", { key = "*", action = api.actions.lock })
        api.set_default_action("open")
    end,
})
