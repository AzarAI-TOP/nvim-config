# nvim-config

A minimal, pure-Lua Neovim configuration for this Windows machine (Neovide +
winget). Plugins are managed by Neovim's built-in `vim.pack`; LSP servers and
portable formatters are managed by Mason. Everything loads at startup — there
is no lazy-loading layer and no hot-reload.

## Requirements

- **Windows 10/11** with **PowerShell** and **winget** (Microsoft App
  Installer). `scripts/bootstrap-windows.ps1` fails fast when winget is missing.
- **Neovim 0.12+** — for `vim.pack` and the native `vim.lsp.completion` APIs.
- **A C compiler on `PATH`** — tree-sitter parsers are compiled locally; this
  machine provides it through CodeBlocks' MinGW via the `~/.local/bin` shims.
- **The `tree-sitter` CLI** — nvim-treesitter drives parser builds through it.
- **StyLua** — the pre-commit hook formats staged Lua files and aborts commits
  it cannot format.
- **Node.js** — the npm-based LSP servers and `prettierd` run on it; today it
  resolves from the agent toolchain on `PATH`.

The config is scoped to the toolchains actually installed here — Go / Rust /
JVM development lives on the Ubuntu box, so their servers, formatters, and
parsers are deliberately absent.

`scripts/bootstrap-windows.ps1` installs the system tools (Git, Neovim,
Neovide, ripgrep, fzf, lazygit, Node.js LTS, Python 3.14), repairs Neovide's
missing `PATH` entry, creates the `Ctrl+Alt+N` Start Menu launcher, installs
the 0xProto Nerd Font and ipython, and then synchronizes every Mason-managed
LSP server and formatter headlessly (`+MasonToolsInstallSync`).

## Layout

```
.
├── init.lua                # entry point — core modules, then plugins, then LSP
├── lua/
│   ├── config/
│   │   ├── util.lua        # unified map() helper, editorconfig indent, tool lists
│   │   ├── options.lua     # editor options + the WinGet PATH probe
│   │   ├── keymaps.lua     # key mappings (leader = <Space>)
│   │   ├── autocmds.lua    # autocommands + per-filetype indent rules
│   │   ├── lsp.lua         # LSP config, diagnostics, native completion, LSP keymaps
│   │   ├── colors.lua      # noice UI colors, statusline gradient, Neovide palette
│   │   ├── neovide.lua     # Neovide GUI settings (no-op outside Neovide)
│   │   └── pack.lua        # :PackUpdate / :PackList
│   └── plugins/            # one file per plugin: vim.pack.add + setup
├── snippets/               # VS Code-format snippet collections (c, cpp, python)
├── scripts/
│   ├── bootstrap-windows.ps1 # system prerequisites + Mason sync
│   └── screen-probe.ps1      # Neovide window/monitor pixel probe
├── .githooks/pre-commit    # auto-formats staged Lua files via StyLua
└── nvim-pack-lock.json     # vim.pack plugin revision lock
```

Each file under `lua/plugins/` is self-contained — it carries its own
`vim.pack.add` alongside its setup — and `lua/plugins/init.lua` loads them all
automatically (a short priority list first, then alphabetically). Adding or
removing a plugin is just adding or removing one file.

## Keymaps

Leader = `<Space>`. `mini.clue` displays the available groups and actions after
a short delay.

| Prefix | Group | Examples |
|--------|-------|----------|
| `<leader>p` | Packages | `pm` Mason UI / `pu` plugin update / `pU` Mason tools update / `pl` plugin list |
| `<leader>s` | Splits | `ss` horizontal / `sv` vertical / `sc` close / `so` close others |
| `<leader>f` | Find | `ff` files / `fc` config / `fr` registers / `fh` help / `ft` TODO / `fk` keymaps / `fn` notifications; `fg` grep project / `fG` live grep |
| `<leader>b` | Buffers | `bn` next / `bp` previous / `bd` delete (`;` opens bento) |
| `<leader>l` | Language | `lf` format / `lD` diagnostics; LSP: `ld` definition / `lh` hover / `lR` references / `lr` rename / `la` code actions / `ls` symbols |
| `<leader>c` | Config | `ce` edit |
| `<leader>e` | File explorer | opens mini.files |
| `<leader>S` | Sessions | `Ss` save / `Sl` load / `Sd` delete |
| `<leader>t` | Terminal | `th` horizontal / `tv` vertical / `tf` float / `tg` lazygit / `tp` ipython (`<F2>` toggles the float) |
| `<leader>u` | Toggles | `uw` wrap / `ui` inlay hints / `uc` completion autotrigger |

Direct keys: `<C-s>` save; `<leader>q` quit. Search: `*` searches without
jumping, `<Esc><Esc>` clears the highlight, `n`/`N` jump and center, `<C-d>`/
`<C-u>` scroll half pages and center. `f`/`F` jump to a character in the line /
window (mini.jump2d). `gc`/`gcc` toggle comments. `]`/`[` navigate diagnostics,
buffers, windows, quickfix and more (mini.bracketed). Native `<C-w>` window
navigation; `<C-Up>`/`<C-Down>`/`<C-Left>`/`<C-Right>` resize.

Completion opens automatically while typing (every printable ASCII keystroke
requests it; multi-byte IME input never triggers). `<C-n>`/`<C-p>` select,
`<C-y>` accepts, `<Tab>` does not accept. Snippets expand on `<C-j>`, with
`<C-l>`/`<C-h>` between fields and `<C-q>` to stop.

## Plugins

bento.nvim · conform.nvim · fzf-lua · mason.nvim · mason-lspconfig.nvim ·
mason-tool-installer.nvim · nvim-lspconfig · noice.nvim · nui.nvim ·
mini.{ai,bracketed,clue,comment,files,git,icons,indentscope,jump2d,move,sessions,snippets,statusline,surround,trailspace} ·
todo-comments.nvim · toggleterm.nvim · tokyonight.nvim · nvim-treesitter ·
nvim-treesitter-textobjects

Mason installs 9 LSP servers (clangd, ts_ls, html, cssls, jsonls, pyright,
lua_ls, bashls, yamlls) and 7 formatters (black, clang-format, isort,
prettierd, shfmt, stylua, taplo).

## Machine-specific notes

- **Clipboard** — the native Windows provider via `win32yank.exe`, which
  Neovim's Windows distribution bundles; `clipboard = "unnamedplus"`.
- **Shell** — `cmd.exe` is pinned for `:!` / `system()` / filters, so a
  Git Bash-launched nvim never feeds cmd-style flags into Bash.
- **Tool discovery** — a Winget portable package can update the user PATH while
  Explorer/Neovide still hold the old environment, so `config/options.lua`
  re-scans the winget package dirs for `fzf` / `lazygit` / `rg` at VimEnter and
  prepends what it finds. `bootstrap-windows.ps1` persists the same directories
  for future shells.
- **Neovide** — 0xProto Nerd Font at 13pt, rounded corners, TokyoNight Moon
  title bar, cursor VFX, and IME auto-switching (on in Insert mode and `/` `?`
  search, off in Normal mode and `:` commands). Launch with `Ctrl+Alt+N` or the
  Start Menu entry.
- **Statusline width probe** — `config/neovide.lua` is a guarded no-op outside
  Neovide, and the probe only runs under Neovide (a terminal nvim has no window
  of its own to measure). `scripts/screen-probe.ps1` reports the client area of
  this instance's window — located via the nvim process's parent, so several
  Neovide instances never cross-measure — against the monitor the window sits
  on. The statusline falls back to its minimal form only below a **quarter** of
  that screen, cached for an hour in the state directory.

## Updating plugins

```vim
:PackUpdate      " vim.pack review buffer (:write applies, :quit discards)
:PackList        " installed plugins
:Mason           " Mason package state
:checkhealth     " full plugin/provider/Mason/toolchain report
```
