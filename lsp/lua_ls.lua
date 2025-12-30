-- lua_ls.lua
-- languange : Lua

local addons_dir = vim.fn.expand(vim.env.LLS_ADDONS_DIR)

---@type vim.lsp.Config
return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    ".stylua.toml",
    "stylua.toml",
    "selene.toml",
    "selene.yml",
    ".git",
  },
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
      },
      signatureHelp = { enabled = true },
      -- Make the server aware of Neovim runtime files
      workspace = {
        checkThirdParty = false,
        library = {
          addons_dir,
        },
        -- or pull in all of 'runtimepath'.
        -- NOTE: this is a lot slower
        -- library = vim.api.nvim_get_runtime_file("", true)
      },
    },
  },
}
