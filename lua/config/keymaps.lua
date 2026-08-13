-- 全局按键绑定。所有按键经 config.util.map 注册并登记到登记表，
-- 供 config.reload 在重载时先删后建。
--
-- <leader> 前缀分组：
--   <leader>b  缓冲区
--   <leader>c  配置
--   <leader>e  文件浏览
--   <leader>f  查找 / 文件
--   <leader>l  语言（格式化 / LSP）
--   <leader>p  包管理
--   <leader>s  分屏
--   <leader>t  开关
--   <leader>w  窗口（转发到 <C-w>）
--
-- LSP 键位（<leader>ld、<leader>lh 等）在 config/lsp.lua 中注册：
-- vim.lsp.buf.* 在无客户端附着的缓冲区中会自动给出原生提示。

local util = require("config.util")
local platform = require("config.platform")

-- ── 顶层：文件 / 会话（无前缀） ──
util.map({ "n", "i" }, "<C-s>", "<Esc>:write<CR>", "保存文件")
util.map("n", "<leader>q", ":quit<CR>", "退出")
util.map("n", "<leader>Q", ":qa<CR>", "全部退出")
if not platform.is_windows and vim.fn.executable("sudo") == 1 then
    util.map("n", "<leader>W", ":write !sudo tee % > /dev/null<CR>", "管理员保存")
end
if platform.is_remote then
    util.map({ "n", "x" }, "<leader>y", '"+y', "复制到宿主机剪贴板")
    util.map("n", "<leader>Y", '"+Y', "复制整行到宿主机剪贴板")
end
util.map("n", "<leader>nh", ":nohlsearch<CR>", "清除搜索高亮")

-- ── <leader>b — 缓冲区 ──
util.map("n", "<leader>bd", ":bdelete<CR>", "删除缓冲区")
util.map("n", "<leader>bn", ":bnext<CR>", "下一个缓冲区")
util.map("n", "<leader>bp", ":bprevious<CR>", "上一个缓冲区")

-- ── <leader>c — 配置 ──
util.map("n", "<leader>ce", ":vsplit $MYVIMRC<CR>", "编辑配置")
util.map("n", "<leader>cr", function() require("config.reload").reload() end, "重载配置")

-- ── <leader>l — 语言（格式化 / LSP） ──
-- 格式化当前缓冲区（conform.nvim）
util.map("n", "<leader>lf", function()
    require("conform").format({ async = true, lsp_format = "fallback" }, function(err, did_edit)
        if err then
            vim.notify("格式化失败: " .. tostring(err), vim.log.levels.ERROR)
        elseif did_edit then
            vim.notify("已格式化", vim.log.levels.INFO)
        else
            vim.notify("无需修改或没有可用的格式化器", vim.log.levels.WARN)
        end
    end)
end, "格式化文件")

-- 诊断详情与导航（不需要 LSP 客户端）
util.map("n", "<leader>le", vim.diagnostic.open_float, "诊断详情")
util.map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "下一个诊断")
util.map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "上一个诊断")

-- ── <leader>e — 文件浏览 ──
util.map("n", "<leader>e", function() require("mini.files").open() end, "文件浏览")

-- ── <leader>f — 查找 / 搜索 ──
util.map("n", "<Leader>ff", function() require("fzf-lua").files() end, "查找文件")
util.map(
    "n",
    "<Leader>fc",
    function() require("fzf-lua").files({ cwd = vim.fn.stdpath("config") }) end,
    "查找配置文件"
)
util.map("n", "<Leader>fr", function() require("fzf-lua").registers() end, "搜索寄存器")
util.map("n", "<Leader>fh", function() require("fzf-lua").helptags() end, "搜索帮助")
util.map("n", "<Leader>ft", ":TodoFzfLua<CR>", "查找 TODO")

-- TODO 注释跳转
util.map("n", "]t", function() require("todo-comments").jump_next() end, "下一个 TODO")
util.map("n", "[t", function() require("todo-comments").jump_prev() end, "上一个 TODO")

-- ── <leader>w — 窗口（转发到 <C-w>） ──
util.map("n", "<leader>w", "<C-w>", "窗口", { remap = true })

-- 直接窗口导航
util.map("n", "<M-h>", "<C-w>h", "左侧窗口")
util.map("n", "<M-j>", "<C-w>j", "下方窗口")
util.map("n", "<M-k>", "<C-w>k", "上方窗口")
util.map("n", "<M-l>", "<C-w>l", "右侧窗口")
util.map("n", "<C-Up>", ":resize -2<CR>", "降低高度")
util.map("n", "<C-Down>", ":resize +2<CR>", "增加高度")
util.map("n", "<C-Left>", ":vertical resize -2<CR>", "减少宽度")
util.map("n", "<C-Right>", ":vertical resize +2<CR>", "增加宽度")

-- ── <leader>s — 分屏 ──
util.map("n", "<leader>ss", ":split<CR>", "水平分屏")
util.map("n", "<leader>sv", ":vsplit<CR>", "垂直分屏")
util.map("n", "<leader>sc", ":close<CR>", "关闭分屏")
util.map("n", "<leader>so", ":only<CR>", "关闭其他分屏")

-- ── <leader>t — 开关 ──
-- 不提供粘贴模式开关：'paste' 在 Neovim 0.12+ 文档中已无记载，
-- 括号粘贴（bracketed paste）会自动处理粘贴场景。
util.map("n", "<leader>tw", ":set wrap!<CR>", "切换自动换行")

-- ── <leader>p — 包管理 ──
util.map("n", "<leader>pm", ":Mason<CR>", "打开 Mason 界面")
util.map("n", "<leader>pu", ":PackUpdate<CR>", "更新插件")
util.map("n", "<leader>pU", ":MasonToolsUpdate<CR>", "更新 Mason 工具")
util.map("n", "<leader>pp", ":PackList<CR>", "列出插件")
util.map("n", "<leader>pi", ":MasonToolsInstallSync<CR>", "安装 Mason 工具")

-- ── 其他直接按键 ──
-- 搜索
util.map("n", "*", "*<C-o>", "搜索光标下单词（不跳转）")
util.map("n", "<Esc><Esc>", ":nohlsearch<CR>", "清除高亮（双击 Esc）")

-- 滚动并居中
util.map("n", "<C-d>", "<C-d>zz", "下翻半页并居中")
util.map("n", "<C-u>", "<C-u>zz", "上翻半页并居中")
util.map("n", "n", "nzzzv", "下一个结果并居中")
util.map("n", "N", "Nzzzv", "上一个结果并居中")

-- 注释（mini.comment）
util.map("n", "<C-/>", "gcc", "切换注释", { remap = true })
util.map("v", "<C-/>", "gc", "切换注释", { remap = true })
