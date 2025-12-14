-- Init nvim's configuration

local function bootstrap_lazy()
    local lazypath = vim.env.LAZY or vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not vim.loop.fs_stat(lazypath) then
        local result = vim.fn.system({
            "git", "clone", "--filter=blob:none",
            "https://github.com/folke/lazy.nvim.git",
            "--branch=stable", lazypath,
        })
        if vim.v.shell_error ~= 0 then
            vim.api.nvim_echo({{"Error cloning lazy.nvim:\n"..result, "ErrorMsg"}}, true, {})
            vim.cmd.quit()
        end
    end
    vim.opt.rtp:prepend(lazypath)
end

local function safe_require(module)
    local ok, mod = pcall(require, module)
    if not ok then
        vim.notify(("Failed to load module %s"):format(module), vim.log.levels.ERROR)
    end
    return mod
end

-- Bootstrap lazy.nvim
bootstrap_lazy()

-- Load modules safely
safe_require("config.options")
safe_require("config.lazy_setup")
safe_require("config.autocmds")
safe_require("config.keymaps")
safe_require("config.lsp_setup")
safe_require("config.diagnostic")
