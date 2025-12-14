-- Autocmds
-- -----------------------------------------------------------------------------
-- Fcitx5 IME auto-switch
-- switch to English IME when exiting from Insert mode
local function setup_fcitx_auto_switch()
  -- check if `fcitx5-remote` command valid
  if vim.fn.executable("fcitx5-remote") == 0 then
    vim.notify("command `fcitx5-remote` not found, this auto-command is disabled.", vim.log.levels.WARN)
    return
  end

  -- switch to English IME
  vim.api.nvim_create_autocmd({ "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("FcitxAutoSwitch", { clear = true }),
    pattern = "*",
    callback = function()
      os.execute("fcitx5-remote -c")
    end,
  })
end
-- Initilize
setup_fcitx_auto_switch()
-- -----------------------------------------------------------------------------
-- LspLog
vim.api.nvim_create_user_command("LspLog", function()
  vim.cmd("edit +$ " .. vim.lsp.get_log_path())
end, {})
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
-- Let Xmake.lua's indent be 4 spaces
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  pattern = "xmake.lua",
  callback = function()
    -- Use 4 spaces per indent
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
  end,
})
