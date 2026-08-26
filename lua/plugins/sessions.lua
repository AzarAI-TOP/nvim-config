-- Named global sessions (mini.sessions): kept under stdpath("data")/session
-- so nothing is ever written into project directories, and auto-updated on
-- exit (autowrite default) after they have been read.

vim.pack.add({
    { src = "https://github.com/nvim-mini/mini.sessions" },
})

require("mini.sessions").setup()
