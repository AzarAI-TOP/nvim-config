-- Nvim-Cmp

---@type LazySpec
return {
    "hrsh7th/nvim-cmp",
    version = false, -- last release is way too old
    event = "InsertEnter",
    dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        -- "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "dcampos/cmp-snippy",
    },

    opts = function()
        local cmp = require("cmp")

        cmp.setup({

            -- Required - must specify a snippet engine
            expand = function(args)
                require("snippy").expand_snippet(args.body) -- For 'snippy' user
                -- vim.snippet.expand(args.body) -- For native neovim snippet
            end,

            window = {
                completion = cmp.config.window.bordered(),
                documentation = cmp.config.window.bordered(),
            },

            sources = cmp.config.sources({
                { name = "snippy" },
                { name = "nvim_lsp" },
                -- { name = "buffer" },
                { name = "path" },
            }),

            formatting = {
                fields = { "abbr", "menu", "kind" },
            },

            mapping = cmp.mapping.preset.insert({
                ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                ["<C-f>"] = cmp.mapping.scroll_docs(4),
                ["<C-Space>"] = cmp.mapping.complete(),
                ["<C-e>"] = cmp.mapping.abort(),
                ["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
            }),
        })
    end,
}
