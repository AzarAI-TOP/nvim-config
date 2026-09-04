-- Buffer management (bento.nvim) — lazy loaded on its sole trigger: the `;`
-- key. The stub mapping loads the plugin (whose setup installs the real `;`
-- mapping) and replays the keypress, so the first `;` opens bento exactly
-- like every later one.

require("config.lazy").defer("bento", {
    keys = { { mode = "n", lhs = ";" } },
    loader = function()
        vim.pack.add({
            { src = "https://github.com/serhez/bento.nvim" },
        })

        require("bento").setup({
            main_keymap = ";",

            ui = {
                mode = "floating",
                floating = {
                    position = "middle-right",
                    border = "rounded",
                },
            },
        })
    end,
})
