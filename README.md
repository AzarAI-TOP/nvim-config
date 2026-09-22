# nvim-config

A minimal, pure-Lua Neovim configuration for this machine (Ubuntu 24.04, kitty
on X11). Plugins are managed by Neovim's built-in `vim.pack`; LSP servers and
formatters are managed by Mason. Everything loads at startup — there is no
lazy-loading layer and no hot-reload.

## Requirements

- **Neovim 0.12+** — for `vim.pack` and the native `vim.lsp.completion` APIs.
  Installed from the classic-confined snap (Ubuntu's apt package is 0.9.5).
- **A C compiler** — tree-sitter parsers compile locally (`build-essential`).
- **The `tree-sitter` CLI (>= 0.26.1)** — nvim-treesitter drives parser builds
  through it. Upstream asks for the release binary, not the npm package.
- **StyLua** — the pre-commit hook formats staged Lua files and aborts commits
  it cannot format.

`scripts/bootstrap-ubuntu.sh` installs all of it (system packages, the pinned
lazygit and tree-sitter CLI binaries, the 0xProto Nerd Font, the git hooks path)
and then syncs every Mason-managed LSP server and formatter headlessly.

## Layout

```
.
├── init.lua                # entry point — core modules, then plugins, then LSP
├── lua/
│   ├── config/
│   │   ├── util.lua        # unified map() helper, editorconfig indent, tool lists
│   │   ├── options.lua     # editor options (number, indent, search, undo, ...)
│   │   ├── keymaps.lua     # key mappings (leader = <Space>)
│   │   ├── autocmds.lua    # autocommands + per-filetype indent rules
│   │   ├── filetypes.lua   # yaml.gitlab / yaml.docker-compose / yaml.helm-values / gotmpl detection
│   │   ├── lsp.lua         # LSP config, diagnostics, native completion, LSP keymaps
│   │   ├── colors.lua      # noice UI colors and the statusline colour gradient
│   │   └── pack.lua        # :PackUpdate / :PackList
│   └── plugins/            # one file per plugin: vim.pack.add + setup
├── snippets/               # VS Code-format snippet collections (c, cpp, python)
├── scripts/
│   ├── bootstrap-ubuntu.sh # system prerequisites + Mason sync
│   └── screen-probe.sh     # screen/window pixel probe for the statusline
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
| `<leader>p` | Packages | `pm` Mason UI / `pu` plugin update / `pt` treesitter parsers / `pU` Mason tools update / `pl` plugin list |
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
buffers, windows, quickfix and more (mini.bracketed).

## Plugins

bento.nvim · conform.nvim · fzf-lua · mason.nvim · mason-lspconfig.nvim ·
mason-tool-installer.nvim · nvim-lspconfig · noice.nvim · nui.nvim ·
mini.{ai,bracketed,clue,comment,files,git,icons,indentscope,jump2d,move,sessions,snippets,statusline,surround,trailspace} ·
todo-comments.nvim · toggleterm.nvim · tokyonight.nvim · nvim-treesitter ·
nvim-treesitter-textobjects

Mason installs 12 LSP servers (gopls, clangd, rust_analyzer, ts_ls, html, cssls,
jsonls, pyright, lua_ls, bashls, yamlls, kotlin_lsp) and 10 formatters (black,
clang-format, goimports, isort, prettierd, shfmt, stylua, taplo,
google-java-format, ktlint). `rustfmt` comes from the Rust toolchain.

## Machine-specific notes

- **Clipboard** — `xclip` on X11, tied to `clipboard = "unnamedplus"`.
- **Shell** — `$SHELL` (bash) is used for `:!` / filters and the terminals.
- **Statusline width probe** — the statusline falls back to its minimal form
  only when the window is narrower than a **quarter of the screen** it sits on.
  `scripts/screen-probe.sh` (`xrandr` + `xwininfo` on `$WINDOWID`) reports the
  screen and window pixel widths, choosing the monitor by the window's position
  — with a 1920x1080 primary and the 2560x1600 laptop panel side by side, "the
  primary" would otherwise be the wrong reference. Results are cached for an
  hour in the state directory.
- **Colors** — kitty's background is set to `#222436` to match tokyonight moon,
  and nvim runs with `transparent = true`, so the terminal padding and the
  editor canvas are the same surface. See `~/.config/kitty/kitty.conf`.

## Updating plugins

```vim
:PackUpdate      " vim.pack review buffer (:write applies, :quit discards)
:TSUpdate        " treesitter parsers — run after :PackUpdate moved nvim-treesitter
                 " (startup install() skips installed parsers; a plugin update
                 "  refreshes queries but not the parser .so files)
:PackList        " installed plugins
:Mason           " Mason package state
:checkhealth     " full plugin/provider/Mason/toolchain report
```

Update order that keeps queries and parsers in sync: `:PackUpdate` → `:restart`
→ `:TSUpdate`. The parsers are pinned by revision inside nvim-treesitter's
repo, so a plugin update with stale parsers produces "Invalid node type"
query errors (kotlin hit this on 2026-09-22).
