-- ~/.config/nvim/lua/config/keymaps.lua
-- Key mappings
--
-- Leader prefix groups:
--   <leader>b  buffer
--   <leader>c  config
--   <leader>l  language (format / LSP)
--   <leader>f  find / file
--   <leader>w  window (forwards to <C-w>)
--   <leader>t  toggle
-- High-frequency file/session ops stay top-level (<C-s> save, etc.).

local function map(mode, lhs, rhs, desc, opts)
    opts = vim.tbl_extend("force", { desc = desc }, opts or {})
    vim.keymap.set(mode, lhs, rhs, opts)
end

local platform = require("config.platform")

-- =============================================
-- Top-level: file / session (no prefix)
-- =============================================
map({ "n", "i" }, "<C-s>", "<Esc>:write<CR>", "Save file")
map("n", "<leader>q", ":quit<CR>", "Quit")
map("n", "<leader>Q", ":qa<CR>", "Quit all")
if not platform.is_windows and vim.fn.executable("sudo") == 1 then
    map("n", "<leader>W", ":write !sudo tee % > /dev/null<CR>", "Sudo save")
end
if platform.is_remote then
    map({ "n", "x" }, "<leader>y", '"+y', "Copy to host clipboard")
    map("n", "<leader>Y", '"+Y', "Copy line to host clipboard")
end
map("n", "<leader>nh", ":nohlsearch<CR>", "Clear search highlight")

-- =============================================
-- <leader>b — buffer
-- =============================================
map("n", "<leader>bd", ":bdelete<CR>", "Delete buffer")
map("n", "<leader>bn", ":bnext<CR>", "Next buffer")
map("n", "<leader>bp", ":bprevious<CR>", "Previous buffer")

-- =============================================
-- <leader>c — config
-- =============================================
map("n", "<leader>ce", ":vsplit $MYVIMRC<CR>", "Edit config")
map("n", "<leader>cr", ":source $MYVIMRC<CR>", "Reload config")

-- =============================================
-- <leader>l — language (format / LSP)
-- =============================================
map("n", "<leader>lf", function()
    require("conform").format({ async = true, lsp_format = "fallback" }, function(err, did_edit)
        if err then
            vim.notify("格式化失败: " .. tostring(err), vim.log.levels.ERROR)
        elseif did_edit then
            vim.notify("已格式化", vim.log.levels.INFO)
        else
            vim.notify("无需修改或没有可用的格式化器", vim.log.levels.WARN)
        end
    end)
end, "Format file")
-- LSP
map("n", "<leader>ld", vim.lsp.buf.definition, "Go to definition")
map("n", "<leader>lh", function() vim.lsp.buf.hover({ border = "rounded" }) end, "Hover documentation")
map("n", "<leader>lr", vim.lsp.buf.references, "Find references")
map("n", "<leader>lR", vim.lsp.buf.rename, "Rename symbol")
map("n", "<leader>la", vim.lsp.buf.code_action, "Code action")
map("n", "<leader>le", vim.diagnostic.open_float, "Diagnostic details")
map("n", "<leader>li", vim.lsp.buf.implementation, "Go to implementation")
map("n", "<leader>ls", function() vim.lsp.buf.signature_help({ border = "rounded" }) end, "Signature help")

-- =============================================
-- <leader>e — explorer
-- =============================================
map("n", "<leader>e", function() require("mini.files").open() end, "File explorer")

-- =============================================
-- <leader>f — find / search
-- =============================================
-- ff   Find files
-- fc   Find in config
-- fr   Search registers
-- fh   Search help
-- ft   Find todos

-- =============================================
-- <leader>w — window (forwards to <C-w>)
-- =============================================
-- <leader>w + <C-w> sub-commands: ws split / wv vsplit / wc close / wo only /
-- wh wj wk wl navigate / w= equal-size, etc.
map("n", "<leader>w", "<C-w>", "Window", { remap = true })

-- Direct window navigation
map("n", "<M-h>", "<C-w>h", "Window left")
map("n", "<M-j>", "<C-w>j", "Window down")
map("n", "<M-k>", "<C-w>k", "Window up")
map("n", "<M-l>", "<C-w>l", "Window right")
map("n", "<C-Up>", ":resize -2<CR>", "Decrease height")
map("n", "<C-Down>", ":resize +2<CR>", "Increase height")
map("n", "<C-Left>", ":vertical resize -2<CR>", "Decrease width")
map("n", "<C-Right>", ":vertical resize +2<CR>", "Increase width")

-- =============================================
-- <leader>t — toggle
-- =============================================
map("n", "<leader>tp", ":set paste!<CR>", "Toggle paste mode")
map("n", "<leader>tw", ":set wrap!<CR>", "Toggle wrap")

-- =============================================
-- Other (direct keys)
-- =============================================
-- Search
map("n", "*", "*<C-o>", "Search word (no jump)")
map("n", "<Esc><Esc>", ":nohlsearch<CR>", "Clear highlight (double Esc)")

-- Scroll and center
map("n", "<C-d>", "<C-d>zz", "Page down half, center")
map("n", "<C-u>", "<C-u>zz", "Page up half, center")
map("n", "n", "nzzzv", "Next result, center")
map("n", "N", "Nzzzv", "Previous result, center")

-- Comment (via mini.comment)
map("n", "<C-/>", "gcc", "Toggle comment", { remap = true })
map("v", "<C-/>", "gc", "Toggle comment", { remap = true })

-- =============================================
-- Plugin mappings
-- =============================================
-- FZF-LUA
map("n", "<Leader>ff", function() require("fzf-lua").files() end, "Find files")
map("n", "<Leader>fc", function() require("fzf-lua").files({ cwd = vim.fn.stdpath("config") }) end, "Find in config")
map("n", "<Leader>fr", function() require("fzf-lua").registers() end, "Search registers")
map("n", "<Leader>fh", function() require("fzf-lua").helptags() end, "Search help")

-- Todo comments
map("n", "<Leader>ft", ":TodoFzfLua<CR>", "Find todos")
map("n", "]t", function() require("todo-comments").jump_next() end, "Next todo")
map("n", "[t", function() require("todo-comments").jump_prev() end, "Previous todo")
