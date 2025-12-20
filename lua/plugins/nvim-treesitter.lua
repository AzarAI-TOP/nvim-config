-- Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  branch = "master",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    ---@diagnostic disable-next-line: missing-fields
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "lua",
        "vim",
        "vimdoc",
        "c",
        "cpp",
        "cmake",
        "python",
        "markdown",
        "markdown_inline",
        "latex",
        "json",
        "jsonc",
        "bash",
        "regex",
        "dart",
      },

      -- Install parsers synchronously (only applied to `ensure_installed`)
      sync_install = true,

      -- Automatically install missing parsers when entering buffer
      -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
      auto_install = true,

      -- List of parsers to ignore installing (or "all")
      ignore_install = {},

      -- If you need to change the installation directory of the parsers (see -> Advanced Setup)
      -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

      highlight = {
        enable = true,

        -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
        -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
        -- the name of the parser)
        --
        -- list of language that will be disabled
        -- disable = {}
        --
        -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
        disable = function(lang, buf)
          local max_filesize = 1024 * 1024 -- 1MB
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then return true end
        end,

        -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
        -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
        -- Using this option may slow down your editor, and you may see some duplicate highlights.
        -- Instead of true it can also be a list of languages
        additional_vim_regex_highlighting = false,
      },

      indent = {
        enable = true,
      },

      fold = {
        enable = false,
      },

      textobjects = {

        -- Built-in Textobjects
        -- @assignment.inner
        -- @assignment.lhs
        -- @assignment.outer
        -- @assignment.rhs
        -- @attribute.inner
        -- @attribute.outer
        -- @block.inner
        -- @block.outer
        -- @call.inner
        -- @call.outer
        -- @class.inner
        -- @class.outer
        -- @comment.inner
        -- @comment.outer
        -- @conditional.inner
        -- @conditional.outer
        -- @frame.inner
        -- @frame.outer
        -- @function.inner
        -- @function.outer
        -- @loop.inner
        -- @loop.outer
        -- @number.inner
        -- @parameter.inner
        -- @parameter.outer
        -- @regex.inner
        -- @regex.outer
        -- @return.inner
        -- @return.outer
        -- @scopename.inner
        -- @statement.outer

        select = {
          enable = true,

          -- Automatically jump forward to textobj, similar to targets.vim
          lookahead = true,

          keymaps = {
            ["af"] = { query = "@function.outer", desc = "function outer" },
            ["if"] = { query = "@function.inner", desc = "function inner" },
            ["ac"] = { query = "@class.outer", desc = "class outer" },
            ["ic"] = { query = "@class.inner", desc = "class inner" },
            ["al"] = { query = "@call.outer", desc = "call outer" },
            ["il"] = { query = "@call.inner", desc = "call inner" },
          },

          -- Choose the select mode of query (default is charwise 'v')
          -- 1. 'v' -- charwise
          -- 2. 'V' -- linewise
          -- 3. '<c-v> -- blockwise
          selection_modes = {
            ["@function.outer"] = "V",
          },

          -- Whether selection is extended to include preceding or succeeding whitespace
          include_surrounding_whitespace = true,
        },
        -- move = {
        --     enable = true,
        --
        --     -- whether to set jumps in the jumplist
        --     set_jumps = true,
        -- },
      },
    })
  end,
}
