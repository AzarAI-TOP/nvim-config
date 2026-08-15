-- TODO/FIX/HACK comment highlighting and search (via vim.pack)
--
-- Integrates with fzf-lua through :TodoFzfLua.
-- Lazy-loaded: setup is deferred until the first file opens, avoiding extra
-- startup work.

vim.pack.add({
    { src = "https://github.com/folke/todo-comments.nvim" },
})

-- Defer setup until a buffer actually opens; a setup failure surfaces as a
-- notification instead of silently disabling :TodoFzfLua for the session.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("todo_comments_lazy", { clear = true }),
    once = true,
    callback = function()
        local ok, err = pcall(function() require("todo-comments").setup() end)
        if not ok then
            vim.notify(
                "todo-comments setup failed: " .. tostring(err),
                vim.log.levels.ERROR,
                { title = "todo-comments" }
            )
        end
    end,
})
