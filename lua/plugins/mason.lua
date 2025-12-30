-- Mason

-- LSP list
local lsp_list = {
  "biome",
  "clangd",
  -- "cmake", disabled because of python version conflict and manually install it
  "gopls",
  "kotlin_lsp",
  "lemminx",
  "lua_ls",
  "marksman",
  "pyright",
  "taplo",
}

local extra_tool_list = {
  "black",
  "clang-format",
  "isort",
  "prettierd",
  "stylua",
}

---@type LazySpec
return {
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      { "williamboman/mason.nvim", opts = {} },
    },
    opts = {
      auto_update = false,
      -- a list of all tools you want to ensure are installed upon
      ensure_installed = lsp_list,
    },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    requires = {
      "williamboman/mason.nvim",
    },
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = extra_tool_list,
      })
    end,
  },
}
