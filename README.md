# nvim-config-mini

A minimal, pure-Lua Neovim configuration for Windows, Fedora desktop, WSL, and
Ubuntu servers. Plugins are managed by Neovim's built-in `vim.pack`; LSP servers
and portable formatters are managed by Mason (requires Neovim 0.12+).

## Layout

```
.
├── init.lua                # entry point — loads config modules, then plugins
├── lua/
│   ├── config/
│   │   ├── options.lua      # editor options (number, indent, search, undo, ...)
│   │   ├── keymaps.lua      # key mappings (leader = <Space>)
│   │   ├── autocmds.lua     # autocommands + per-filetype indent rules
│   │   ├── lsp.lua          # LSP config (native vim.lsp.config API)
│   │   ├── neovide.lua      # shared Windows/Fedora Neovide settings
│   │   ├── platform.lua     # Windows/Linux/WSL/SSH detection
│   │   └── tools.lua        # shared LSP/formatter/system-tool inventory
│   ├── nvim_config/
│   │   └── health.lua       # :checkhealth nvim_config
│   ├── lsp/
│   │   ├── gopls.lua        # Go Language Server config
│   │   ├── lua_ls.lua       # Lua Language Server config
│   │   ├── pyright.lua      # Pyright config
│   │   ├── rust_analyzer.lua # rust-analyzer config
│   │   └── yamlls.lua       # YAML Language Server config
│   └── plugins/
│       ├── init.lua         # auto-loader — requires every other file in this dir
│       ├── bento.lua        # bento.nvim — buffer manager
│       ├── conform.lua      # conform.nvim — code formatting
│       ├── fzf.lua          # fzf-lua — fuzzy finding
│       ├── mason.lua        # mason + mason-lspconfig plugin declarations
│       ├── mini-bracketed.lua  # mini.bracketed — bracket navigation
│       ├── mini-core.lua    # mini.ai / .comment / .icons / .indentscope / .move / .trailspace
│       ├── mini-files.lua   # mini.files — file explorer
│       ├── mini-notify.lua  # mini.notify — notification system
│       ├── todo-comments.lua    # todo-comments.nvim — TODO highlighting
│       ├── tokyonight.lua   # tokyonight (moon) colorscheme
│       └── treesitter.lua   # nvim-treesitter — syntax highlighting
├── scripts/
│   ├── bootstrap-linux.sh   # Fedora/Ubuntu/WSL system prerequisites
│   └── bootstrap-windows.ps1 # Windows system prerequisites
├── tests/                   # headless startup/config/platform checks
├── .githooks/
│   ├── pre-commit           # auto-format staged Lua files via StyLua
│   └── README.md
└── .stylua.toml            # StyLua formatter config
```

Each file under `lua/plugins/` is self-contained — it carries its own
`vim.pack.add` alongside its setup — and `lua/plugins/init.lua` loads them all
automatically. Adding or removing a plugin is just adding or removing one file.
Per-server LSP configs live in `lua/lsp/<server>.lua` and are auto-loaded
by `lua/config/lsp.lua`.

## Highlights

- **No third-party plugin manager** — plugins are installed via
  Neovim's built-in `vim.pack`; update with `:Pack update`.
- **Buffer manager** — `bento.nvim` (`<leader>bb`) provides a floating buffer switcher
  with actions (open, delete, split, lock).
- **File explorer** — `mini.files` uses Miller columns for navigating and
  manipulating the file system. Replaces netrw by default.
- **Fuzzy finding** — `fzf-lua` for files (`<leader>ff`), config (`<leader>fc`),
  registers (`<leader>fr`), help (`<leader>fh`).
- **Code formatting** — `conform.nvim` formats on demand (`<leader>lf`). Mason
  installs portable formatters automatically; `gofmt` and `rustfmt` come from
  their native Go/Rust toolchains.
- **Tree-sitter syntax highlighting** — 22 parsers installed, enabled
  automatically on matching filetypes; falls back to regex otherwise.
- **Textobjects** — `mini.ai` extends `a`/`i` with function calls, arguments,
  tags, and more. Supports consecutive expansion (`in` → `in` → ...).
- **Bracket navigation** — `mini.bracketed` provides `]`/`[` mappings for
  diagnostics, indentation, comments, quickfix, buffers, windows, and more.
- **Comment toggling** — `mini.comment` via `gc` / `gcc` / `<C-/>`.
- **Leader = `<Space>`**, with mappings grouped by mnemonic prefix:
  `<leader>b` buffer, `<leader>c` config, `<leader>l` language (format),
  `<leader>e` explorer, `<leader>f` find/search, `<leader>t` toggle.
  Direct window navigation via `<M-h/j/k/l>`.
- **Per-filetype indentation** — 2 spaces for web/scripting/markup languages,
  4 spaces for systems languages, tabs for Go/Make.
- **Quality-of-life autocmds** — highlight on yank, restore last cursor
  position.
- **TODO highlighting** — `todo-comments.nvim` highlights and searches for
  TODO/FIX/HACK/WARN/NOTE comments.
- **Notifications** — `mini.notify` replaces `vim.notify` with a cleaner UI.
- **Visual aides** — `mini.indentscope` shows indent guides,
  `mini.trailspace` highlights trailing whitespace,
  `mini.move` moves lines/selections with `Alt+↑/↓`.
- Persistent undo, system clipboard integration, `termguicolors`.
- Deterministic plugin/LSP config loading on NTFS and Linux filesystems.
- Native clipboard on Windows/Fedora; OSC52 clipboard for WSL and SSH.

## Plugins

| Plugin | Purpose |
|--------|---------|
| [bento.nvim](https://github.com/serhez/bento.nvim) | Buffer manager |
| [conform.nvim](https://github.com/stevearc/conform.nvim) | Code formatting |
| [fzf-lua](https://github.com/ibhagwan/fzf-lua) | Fuzzy finding |
| [mason.nvim](https://github.com/mason-org/mason.nvim) | External tool package manager |
| [mason-lspconfig.nvim](https://github.com/mason-org/mason-lspconfig.nvim) | LSP installation bridge |
| [mason-tool-installer.nvim](https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim) | Formatter installation |
| [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | Native LSP defaults |
| [mini.ai](https://github.com/nvim-mini/mini.ai) | Textobjects |
| [mini.bracketed](https://github.com/nvim-mini/mini.bracketed) | Bracket navigation |
| [mini.comment](https://github.com/nvim-mini/mini.comment) | Comment toggling |
| [mini.files](https://github.com/nvim-mini/mini.files) | File explorer |
| [mini.icons](https://github.com/nvim-mini/mini.icons) | Icon provider |
| [mini.indentscope](https://github.com/nvim-mini/mini.indentscope) | Indent guides |
| [mini.move](https://github.com/nvim-mini/mini.move) | Move lines/selections |
| [mini.notify](https://github.com/nvim-mini/mini.notify) | Notification system |
| [mini.trailspace](https://github.com/nvim-mini/mini.trailspace) | Trailing whitespace |
| [todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | TODO highlighting |
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Colorscheme (moon) |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Syntax highlighting |

## Install

### Windows

```powershell
git clone https://github.com/AzarAI-TOP/nvim-config "$env:LOCALAPPDATA\nvim"
Set-Location "$env:LOCALAPPDATA\nvim"
.\scripts\bootstrap-windows.ps1
```

The Windows bootstrap installs Neovim, Neovide, Git, Node, Python, Go, Rust,
Java, LLVM, fzf, ripgrep, 7-Zip, and the 0xProto Nerd Font before synchronizing
all Mason-managed LSP servers and formatters.

### Fedora / Ubuntu / WSL

```sh
git clone https://github.com/AzarAI-TOP/nvim-config "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
cd "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
bash scripts/bootstrap-linux.sh
```

The Linux bootstrap script:

- installs `git`, `curl`, compilers, Node, Go, Rust, Java, `fzf`, and `ripgrep`;
- installs Neovim under `~/.local` when the distro version is older than 0.12;
- installs both `wl-clipboard` and `xclip` for Fedora desktop, even when run
  from TTY/SSH; set `INSTALL_DESKTOP_DEPS=0` for a headless Fedora host;
- replaces distro `fzf` with a user-local current release when it is older
  than the fzf-lua minimum (0.36);
- installs 0xProto Nerd Font on Fedora desktop (disable with
  `INSTALL_0XPROTO_FONT=0`);
- runs Mason's synchronous LSP server and formatter installation.

Ensure `~/.local/bin` is in your shell `PATH` after bootstrap.

## Platform behavior

| Environment | UI | Clipboard | Shell |
|-------------|----|-----------|-------|
| Windows | terminal / Neovide | native Windows provider | `cmd.exe` pinned for `:!` compatibility |
| Fedora desktop | terminal / Neovide | `wl-clipboard` (Wayland) or `xclip` (X11) | inherited user shell |
| WSL | terminal | OSC52 through the host terminal | inherited Linux shell |
| Ubuntu over SSH | terminal | OSC52 through the SSH terminal | inherited Linux shell |

OSC52 copy works in modern terminals such as Windows Terminal, WezTerm, Kitty,
and recent GNOME Terminal. Clipboard *read* may require explicit terminal
permission; normal terminal paste remains available regardless.

Neovide uses 0xProto Nerd Font at 13pt on Windows and Fedora. Windows-only title
bar and rounded-corner settings are not applied on Linux.

## Verification

Run the isolated headless suite from the repository root. The wrapper copies
the working tree into a disposable XDG directory, disables background tool
downloads, and removes it afterwards.

```sh
bash scripts/test-config.sh
```

On Windows PowerShell:

```powershell
.\scripts\test-config.ps1
```

Inside Neovim, run `:checkhealth nvim_config` for platform-specific system-tool,
clipboard, and toolchain diagnostics. `:checkhealth` provides the full plugin
and provider report.

## Future Considerations

These upstream changes may affect this config in the near future:

- **bento.nvim v2** — A `feat/v2` branch with a fully refactored API
  (explicit action/key registration via `require("bento.api")`) is planned for
  merge to `main` around **July 2026**. The current `setup({ main_keymap = "<leader>bb" })`
  config will need updating when that lands.
- **nvim-treesitter archived** — The repository was archived on 2026-04-03 and
  is no longer actively developed. The current `main`-branch API works correctly
  for now. Long-term, Neovim 0.12+'s built-in `vim.treesitter` may be a
  sufficient replacement for syntax highlighting.
