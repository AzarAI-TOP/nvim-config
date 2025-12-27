-- Nvim-Cmp

---@type LazySpec
return {
  "hrsh7th/nvim-cmp",
  version = false, -- last release is way too old
  event = "InsertEnter",
  dependencies = {
    -- Snippet engine
    "dcampos/cmp-snippy",
    "dcampos/nvim-snippy",

    -- Completion sources
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
  },

  opts = function()
    local cmp = require("cmp")
    local snippy = require("snippy")

    snippy.setup({
      enable_auto = true,
      mappings = { is = {
        ["<Tab>"] = "expand_or_advance",
        ["<S-Tab>"] = "previous",
      } },
    })

    cmp.setup({
      -- Required - must specify a snippet engine
      -- snippet = {
        -- expand = function(args)
          -- require("snippy").expand_snippet(args.body) -- For 'snippy' user
          -- vim.snippet.expand(args.body) -- For native neovim snippet
        -- end,
      -- },

      window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
      },

      sources = cmp.config.sources({
        -- { name = "snippy" },
        { name = "nvim_lsp", max_item_count = 10 },
        { name = "path" },
      }, {
        { name = "buffer" },
      }),

      formatting = {
        fields = { "abbr", "menu", "kind" },
      },

      mapping = cmp.mapping.preset.insert({
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<C-d>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({ select = false }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.

        -- ["<Tab>"] = cmp.mapping(function(fallback)
        --   if snippy.can_expand_or_advance() then
        --     snippy.expand_or_advance()
        --     fallback()
        --   end
        -- end, { "i" }),

        ["<Tab>"] = cmp.mapping(function(fallback)
          if snippy.can_expand_or_advance() then
            snippy.next()
          else
            fallback()
          end
        end, { "i", "s" }),

        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if snippy.can_jump(-1) then
            snippy.previous()
          else
            fallback()
          end
        end, { "i", "s" }),
      }),
    })
  end,
}

