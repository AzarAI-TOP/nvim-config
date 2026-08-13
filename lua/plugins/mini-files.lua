-- 文件浏览器（mini.files，经 vim.pack）
--
-- 使用 Miller 列式导航；替代 netrw 成为默认文件浏览器；
-- 可用时自动使用 mini.icons 提供文件图标。

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.files" },
})

require("mini.files").setup({
    options = {
        -- 替代 `:e <目录>` 等场景中的 netrw
        use_as_default_explorer = true,
    },
    windows = {
        preview = true, -- 显示光标下文件的预览
    },
})
