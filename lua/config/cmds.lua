-- Commands user defined

-- LSP log
vim.api.nvim_create_user_command("LspLog", function()
  vim.cmd("edit +$ " .. vim.lsp.get_log_path())
end, {
  desc = "Open LSP log file",
})
