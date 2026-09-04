-- Mason: package manager, LSP-name bridge, and tool installer — deferred.
--
-- Command stubs make :Mason* resolve instantly; the real plugins load either
-- on the first :Mason* command or 1s after VimEnter, whichever comes first.
-- The timer preserves mason-tool-installer's run_on_start semantics — its
-- background install check still happens after startup, just not on the
-- startup critical path. Setup itself only registers commands / UI (no
-- network); NVIM_BOOTSTRAP=1 makes config.lazy load everything immediately
-- so the bootstrap flow installs up front via `+MasonToolsInstallSync`.

local lazy = require("config.lazy")

lazy.defer("mason", {
    cmds = { "Mason", "MasonToolsUpdate", "MasonToolsInstall", "MasonToolsInstallSync", "MasonToolsClean" },
    loader = function()
        vim.pack.add({
            -- mason-org is the upstream home; the old williamboman/* URLs survive
            -- only via GitHub rename redirects, so don't depend on them.
            { src = "https://github.com/mason-org/mason.nvim" },
            -- Maps nvim-lspconfig server names (lua_ls, ts_ls, ...) to Mason
            -- package names for mason-tool-installer; activation of the servers
            -- themselves is handled by config/lsp.lua via vim.lsp.enable().
            { src = "https://github.com/mason-org/mason-lspconfig.nvim" },
            { src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
        })

        local automated = vim.env.NVIM_BOOTSTRAP == "1"
        local ok, err = pcall(function()
            require("mason").setup()
            require("mason-lspconfig").setup({ automatic_enable = false })
            require("mason-tool-installer").setup({
                ensure_installed = require("config.util").mason_packages,
                auto_update = false,
                run_on_start = not automated,
                start_delay = 1000,
                debounce_hours = 24,
            })
        end)
        if not ok then vim.notify("Mason init failed: " .. tostring(err), vim.log.levels.ERROR, { title = "mason" }) end
    end,
})

-- Post-startup background tool check (see header): load mason 1s after the
-- editor is up; mason-tool-installer then schedules its own debounced check.
if vim.env.NVIM_BOOTSTRAP ~= "1" then
    vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
            vim.defer_fn(function() lazy.load_now("mason") end, 1000)
        end,
    })
end
