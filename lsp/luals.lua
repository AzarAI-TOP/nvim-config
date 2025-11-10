-- luals.lua
-- languange : Lua

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
      workspace = {
        library = {
          vim.env.VIMRUNTIME,
          "$XDG_DATA_HOME/nvim/lazy"
        },
      },
    },
  },
}
