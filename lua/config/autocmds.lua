-- Autocmds
-- -----------------------------------------------------------------------------
--- Setup fcitx5 IME auto-switching
--- Automatically switches to English IME when leaving insert mode
--- @return boolean True if setup successful, false otherwise
function Setup_fcitx5_autoswitch()
  -- Check if fcitx5-remote command is available
  if vim.fn.executable("fcitx5-remote") == 0 then return false end

  -- Switch to English IME
  local function switch_to_english()
    os.execute("fcitx5-remote -c")
  end

  -- Create autocommand to switch when leaving insert mode
  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("Fcitx5AutoSwitch", { clear = true }),
    pattern = "*",
    callback = switch_to_english,
    desc = "Switch to English IME when leaving insert mode",
  })

  return true
end
-- Initilize
Setup_fcitx5_autoswitch()
-- -----------------------------------------------------------------------------
-- Set cursor at the position of last edit
vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = "*",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
  end,
})
-- -----------------------------------------------------------------------------
