-- Utility module for useful functions
local M = {}

---Set keymaps
---@param mode string keymap mode
---@param lhs string trigger
---@param rhs string|fun() action
---@param desc string description
---@param extra_opts? table extra options
function M.default_keymap(mode, lhs, rhs, desc, extra_opts)
  extra_opts = extra_opts or {}

  -- Set remap's default value equals to false
  if extra_opts.remap == nil then extra_opts.remap = false end

  local opts = vim.tbl_extend("force", { silent = true, desc = desc }, extra_opts)

  for m in mode:gmatch(".") do
    vim.keymap.set(m, lhs, rhs, opts)
  end
end

return M
