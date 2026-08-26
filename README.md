# nvim-config

A minimal, pure-Lua Neovim configuration for Windows. Plugins are managed by
Neovim's built-in `vim.pack`; LSP servers and portable formatters are managed
by Mason (requires Neovim 0.12+).

## Layout

```
.
├── init.lua                # entry point — loads config modules, then plugins
├── lua/
│   ├── config/
│   │   ├── util.lua        # keymap registry, unified map(), :PackList rows,
│   │   │                   #   indent helpers, tool inventory
│   │   ├── options.lua     # editor options (number, indent, search, undo, ...)
│   │   ├── keymaps.lua     # key mappings (leader = <Space>)
│   │   ├── autocmds.lua    # autocommands + per-filetype indent rules
│   │   ├── lsp.lua         # all LSP config: per-server tables, diagnostics,
│   │   │                   #   native completion activation, LSP keymaps
│   │   ├── colors.lua      # noice UI colors: popupmenu/kind palette (moon),
│   │   │                   #   transparent float surfaces, per-kind groups
│   │   ├── neovide.lua     # Neovide GUI settings
│   │   ├── pack.lua        # :PackUpdate / :PackList user commands
│   │   └── reload.lua      # hot-reload of the core config layer
│   └── plugins/            # one file per plugin: vim.pack.add + setup
│       ├── init.lua        # loader — priority list, then alphabetical
│       └── <name>.lua      # mason, tokyonight, fzf, mini, conform, ...
├── scripts/
│   └── bootstrap-windows.ps1 # Windows system prerequisites
├── .githooks/pre-commit    # auto-formats staged Lua files via StyLua
└── .stylua.toml            # StyLua formatter config
```

Each file under `lua/plugins/` is self-contained — it carries its own
`vim.pack.add` alongside its setup — and `lua/plugins/init.lua` loads them all
automatically (a short priority list first, then alphabetically). Adding or
removing a plugin is just adding or removing one file. Per-server LSP configs
live as inline tables in `lua/config/lsp.lua`, alongside the diagnostic
display, native completion activation, and the LSP keymaps.

## Highlights

- **No third-party plugin manager** — plugins are installed via
  Neovim's built-in `vim.pack`; update with `:PackUpdate` (opens the official
  vim.pack review buffer — `:write` applies, `:quit` discards), list them with
  `:PackList`.
- **Buffer manager** — `bento.nvim` (`;`) provides a floating buffer switcher
  with actions (open, delete, split, lock).
- **File explorer** — `mini.files` uses Miller columns for navigating and
  manipulating the file system. Replaces netrw by default.
- **Fuzzy finding** — `fzf-lua` for files (`<leader>ff`), config (`<leader>fc`),
  registers (`<leader>fr`), help (`<leader>fh`).
- **Character jumping** — `hop.nvim`: `f` searches within the current line,
  `F` across the whole window (replacing the built-in `f`/`F` motions).
- **Terminals** — `toggleterm.nvim`: `<leader>th` toggles a horizontal
  terminal, `<leader>tv` a vertical one, `<leader>tf` / `<F2>` a floating one,
  `<leader>tg` lazygit, `<leader>tp` ipython.
- **Native LSP completion + snippets** — Neovim 0.12 completion is enabled
  per attached client and opens automatically on every printable character
  (the server's trigger characters are extended to all printable ASCII);
  the popup never auto-selects. `mini.snippets` loads the
  local C, C++, and Python collections from `snippets/`; type a prefix and
  press `<C-j>` to expand, then `<C-l>` / `<C-h>` to move between fields and
  `<C-q>` to stop the session.
  Markdown disables LSP completion to keep prose input immediate, while snippet expansion remains available.
- **Simple plugin lifecycle** — every plugin registers its own
  `vim.pack.add` and setup; Mason sets up synchronously at startup (registry
  and command registration only — tool installs happen after startup via the
  configured `run_on_start`). Bootstrap mode (`NVIM_BOOTSTRAP=1`) keeps the
  automatic check disabled so `+MasonToolsInstallSync` runs eagerly and
  headless runs never hit the network. Tokyo Night prepares on
  `ColorSchemePre`; TODO comments initialize on the first opened file.
- **Key discovery** — `mini.clue` acts as a lightweight which-key for
  `<leader>`, `[` and `]`, without adding a second overlapping hint UI.
- **Code formatting** — `conform.nvim` formats on demand (`<leader>lf`). Mason
  installs portable formatters automatically; `gofmt` and `rustfmt` come from
  their native Go/Rust toolchains. Java uses `google-java-format`, Kotlin uses
  `ktlint`, shell uses four spaces, C/C++ prefers the project `.clang-format`
  (Google Style only as fallback outside any configured project), and
  prettierd prefers project configuration while falling back to Prettier's
  built-in defaults when no project configuration exists.
- **Tree-sitter syntax highlighting** — every configured parser enabled
  automatically on matching filetypes; falls back to regex otherwise.
- **Textobjects** — `mini.ai` extends `a`/`i` with arguments, function calls,
  quotes, brackets, tags, and more. A custom treesitter target `aF` / `iF`
  selects a whole function definition (outer with braces, inner body only),
  backed by nvim-treesitter-textobjects' capture queries. Supports consecutive
  expansion (`in` → `in` → ...).
- **Bracket navigation** — `mini.bracketed` provides `]`/`[` mappings for
  diagnostics, indentation, comments, quickfix, buffers, windows, and more;
  pausing after either prefix displays the available targets through `mini.clue`.
- **Comment toggling** — `mini.comment` via `gc` / `gcc` / `<C-/>`.
- **Surround editing** — `mini.surround`: `sa` adds a surrounding pair,
  `sd` deletes it, `sr` replaces it (visual mode: `S`).
- **Leader = `<Space>`**, with mappings grouped by mnemonic prefix:
  `<leader>b` buffer, `<leader>c` config, `<leader>l` language (format),
  `<leader>e` explorer, `<leader>f` find/search, `<leader>t` terminal,
  `<leader>u` toggles. Window navigation goes through the `<leader>w` prefix.
- **Per-filetype indentation** — 2 spaces for web/scripting/markup languages,
  4 spaces for systems languages, tabs for Go/Make. Project `.editorconfig`
  values (full property and glob support via the runtime module) take
  precedence over these defaults. C/C++/ObjC default to Google Style (2-space
  indent) to match clang-format's fallback; a project `.clang-format`
  (searched upward from the file) overrides via its `IndentWidth`/`TabWidth`/
  `UseTab`/`BasedOnStyle` keys, and `.editorconfig` still wins over both.
- **Real config reload** — `<leader>cr` reloads the core config layer
  (options, keymaps, autocmds, LSP, Neovide settings, pack commands) for
  real: tracked keymaps are re-created, owned commands rebuilt, config
  modules re-required in startup order. Plugin-file changes (setup options,
  parsers, colorscheme style) still require a restart.
- **Quality-of-life autocmds** — highlight on yank, restore last cursor
  position.
- **TODO highlighting** — `todo-comments.nvim` highlights and searches for
  TODO/FIX/HACK/WARN/NOTE comments.
- **Sessions** — `mini.sessions` snapshots the workspace (buffers, windows,
  cwd, folds) into named global sessions under the data directory (nothing is
  written into projects): `<leader>Ss` saves under a prompted name, `<leader>Sl`
  restores or switches, `<leader>Sd` deletes. A restored session auto-updates
  on exit.
- **Notifications** — `mini.notify` replaces `vim.notify` with a cleaner UI.
- **Visual aides** — `mini.indentscope` shows indent guides,
  `mini.trailspace` highlights trailing whitespace,
  `mini.move` moves lines/selections with `Alt+↑/↓`.
- Persistent undo, native system clipboard integration, `termguicolors`.
- Deterministic plugin/LSP config loading (sorted module discovery).

## Plugins

| Plugin | Purpose |
|--------|---------|
| [bento.nvim](https://github.com/serhez/bento.nvim) | Buffer manager |
| [conform.nvim](https://github.com/stevearc/conform.nvim) | Code formatting |
| [fzf-lua](https://github.com/ibhagwan/fzf-lua) | Fuzzy finding |
| [hop.nvim](https://github.com/smoka7/hop.nvim) | Character jumping |
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
| [mini.sessions](https://github.com/nvim-mini/mini.sessions) | Per-directory session persistence |
| [mini.statusline](https://github.com/nvim-mini/mini.statusline) | Statusline |
| [mini.snippets](https://github.com/nvim-mini/mini.snippets) | Local C/C++/Python snippet expansion |
| [mini.surround](https://github.com/nvim-mini/mini.surround) | Surround editing |
| [mini.clue](https://github.com/nvim-mini/mini.clue) | Leader-key discovery and groups |
| [mini.trailspace](https://github.com/nvim-mini/mini.trailspace) | Trailing whitespace |
| [todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | TODO highlighting |
| [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) | Toggleable terminals (terminal / lazygit / ipython) |
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Colorscheme (moon) |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Syntax highlighting |
| [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) | Textobject capture queries (consumed by mini.ai; the plugin itself stays unloaded) |

## Install

```powershell
winget install --id Git.Git --exact --accept-package-agreements --accept-source-agreements
$env:Path = @([Environment]::GetEnvironmentVariable("Path", "Machine"), [Environment]::GetEnvironmentVariable("Path", "User")) -join ";"
git clone https://github.com/AzarAI-TOP/nvim-config "$env:LOCALAPPDATA\nvim"
Set-Location "$env:LOCALAPPDATA\nvim"
git config core.hooksPath .githooks
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1
```

The pre-commit hook is fail-closed: commits touching Lua files are aborted
unless StyLua (PATH, Mason packages, or Mason bin) can format them.

The Windows bootstrap installs Neovim, Neovide, Git, Node, Python, Go, Rust,
Java, LLVM, fzf, lazygit, ripgrep, 7-Zip, and the 0xProto Nerd Font, installs
ipython via pip (the `<leader>tp` REPL), and then synchronizes all
Mason-managed LSP servers and formatters.

## Platform behavior

- **Clipboard** — native Windows provider, `clipboard = "unnamedplus"` (yank
  and paste go through the system clipboard).
- **Shell** — `cmd.exe` is pinned for `:!` / `system()` / filters so a Git
  Bash-launched nvim never feeds cmd-style flags into Bash.
- **Tool discovery** — at startup the config checks WinGet package dirs
  (`%LOCALAPPDATA%\Microsoft\WinGet\Packages`) for `fzf` / `lazygit` and
  prepends them to `PATH` when a stale Explorer/Neovide environment hides
  them.
- **Neovide** — 0xProto Nerd Font at 13pt, rounded corners, title bar in
  TokyoNight Moon colors.

### Launching Neovide

Press `Ctrl+Alt+N` to launch Neovide via the Start Menu shortcut (installed
automatically by the bootstrap). Alternatively, run `neovide` from PowerShell
after the bootstrap adds it to your user `PATH`, or find "Neovide" in the
Start Menu.

IME auto-toggles for Chinese input: on in Insert mode and `/` / `?` search,
off in Normal mode and `:` commands.

## Troubleshooting

This config ships no automated test suite — verify by using the editor and
checking its built-in diagnostics:

```vim
:checkhealth               " full plugin/provider/Mason/toolchain report
:MasonToolsInstallSync     " (re)install all Mason-managed LSP servers and formatters
:Mason                     " inspect package state in the Mason UI
:PackUpdate                " update plugins via the vim.pack review buffer
```

The bootstrap script installs every dependency it declares and fails fast on
any unacceptable exit code (winget exit codes and SHA-256 checksum
verification). If something is missing afterwards, `:checkhealth` names the
tool and the fix.

## Key map groups

Press `<Space>`, `[` or `]`; `mini.clue` displays the available groups and
actions after a short delay. Existing mapping descriptions provide action hints,
while explicit clues label the mnemonic `<leader>` groups below.

| Prefix | Group | Examples |
|--------|-------|----------|
| `<leader>p` | Package management | `pm` Mason UI / `pu` plugin update / `pU` Mason tools update / `pl` plugin list / `pi` install |
| `<leader>s` | Splits | create/close/keep split |
| `<leader>f` | Find | files/config/registers/help/TODO/keymaps; `fg` grep project / `fG` live grep / `fW` word under cursor |
| `<leader>b` | Buffers | next/previous/delete (`;` opens bento directly) |
| `<leader>l` | Languages | format / LSP actions (def, hover, rename, references, symbols, signature) / diagnostics |
| `<leader>c` | Config | edit/reload config |
| `<leader>e` | File explorer | `e` opens mini.files (Miller columns) |
| `<leader>S` | Sessions | `Ss` save / `Sl` load / `Sd` delete |
| `<leader>t` | Terminal | `th` horizontal / `tv` vertical / `tf` float / `tg` lazygit / `tp` ipython (`<F2>` toggles the float; in terminal mode, toggles the terminal under the cursor) |
| `<leader>u` | Toggles | wrap / inlay hints |
| `<leader>w` | Windows | forwards to native `<C-w>` commands |

Diagnostic navigation uses `]d` / `[d` (and `]D` / `[D` for first/last), plus
`]b`/`[b` buffers, `]w`/`[w` windows, `]q`/`[q` quickfix/location, `]f`/`[f`
files, `]o`/`[o` oldfiles, `]u`/`[u` undo and more — all provided by
mini.bracketed; there are no duplicate `<leader>ln` / `<leader>lp` aliases.
LSP actions are global and use Neovim's built-in "no client attached" feedback
outside LSP buffers.

## Completion and snippets

- LSP completion opens automatically while typing (every printable character
  is a trigger character). Use `<C-Space>` for a manual request. The popup
  never auto-selects or auto-inserts: move with `<C-n>`/`<C-p>`, accept with
  `<C-y>`. `<Tab>` does not accept — it closes the menu and keeps its usual
  indentation behavior.
- Snippets: type `main`, `for`, `if`, `def`, etc., then press `<C-j>` to
  expand. During a snippet session, `<C-l>` jumps to the next field and
  `<C-h>` (the same key as Backspace) to the previous one; `<C-q>` stops the
  session. Expansion is strict (exact prefix or fuzzy match on the typed
  word): the all-snippets picker never appears, so `<Tab>` keeps working for
  indentation.
- Snippet files live in `snippets/c.json`, `snippets/cpp.json`, and
  `snippets/python.json`; they use VS Code/LSP snippet JSON syntax. Loaders
  cache file contents, so after editing a snippet file restart Neovim or run
  `MiniSnippets.setup(MiniSnippets.config)` to clear the cached loaders.
- Markdown disables LSP completion to keep prose input immediate, but retains
  the snippet mechanism and its `<C-j>` expand mapping. No `markdown.json`
  snippet file is bundled; add one under `snippets/` to use snippets in
  Markdown.

## Future Considerations

These upstream changes may affect this config in the near future:

- **bento.nvim v2** — A `feat/v2` branch with a fully refactored API
  (explicit action/key registration via `require("bento.api")`) was announced
  for a July 2026 merge, which has since passed. Before updating bento,
  verify the current `main` API — `setup({ main_keymap = ";" })` may need
  changes when v2 lands.
- **nvim-treesitter archived** — The repository was archived on 2026-04-03 and
  is no longer actively developed. The current `main`-branch API works correctly
  for now. Long-term, Neovim 0.12+'s built-in `vim.treesitter` may be a
  sufficient replacement for syntax highlighting.
- **nvim-treesitter-textobjects archived** — Archived on 2026-04-03 in the same
  wave. It is consumed purely as query data by mini.ai's `F` target, which
  keeps working without maintenance. Once a future Neovim version ships
  built-in textobject queries, this dependency can be dropped.
