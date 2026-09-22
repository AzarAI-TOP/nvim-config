-- Derived yaml filetype (config/filetypes.lua). The runtime's
-- ftplugin/yaml.vim only loads for the exact filetype "yaml", so re-apply its
-- buffer settings here: '#' comments and YAML format options.
vim.bo.comments = ":#"
vim.bo.commentstring = "# %s"
vim.bo.formatoptions:remove("t")
vim.bo.formatoptions:append("croql")
