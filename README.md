# Nvim-config

A minimal, pure-Lua Neovim configuration for Windows. Plugins are managed by
Neovim's built-in `vim.pack`; LSP servers and portable formatters are managed
by Mason (requires Neovim 0.12+).

## Requirements

The config is Windows-only and bootstraps everything it needs; the only real
preconditions are a **Windows 10/11** machine with **PowerShell** and
**winget** (Microsoft App Installer). The bootstrap script fails fast when
winget is missing.

Config-level requirements:

- **Neovim 0.12+** — needed for `vim.pack` and the native
  `vim.lsp.completion` APIs. The bootstrap installs Neovim and then verifies
  the version, aborting on anything older.
- **A C compiler on `PATH`** — tree-sitter parsers are compiled locally (the
  bootstrap installs LLVM, which provides `clang`).
- **StyLua** — the pre-commit hook (`.githooks/pre-commit`) formats staged
  Lua files and aborts commits it cannot format. The hook resolves StyLua
  from `PATH` first, then from Mason's install directories.

The bootstrap (`scripts/bootstrap-windows.ps1`) installs the remaining system
tools: Git, Neovim, Neovide, Node.js LTS, Python 3.13, Go, Rust (rustup +
stable toolchain + rustfmt), OpenJDK 21, LLVM, ripgrep, fzf, lazygit, 7-Zip,
the 0xProto Nerd Font, and ipython (via pip).

Mason installs and updates the LSP servers and portable formatters:

| Kind | Tools |
|------|-------|
| LSP servers | `gopls`, `clangd`, `rust_analyzer`, `ts_ls`, `html`, `cssls`, `jsonls`, `pyright`, `lua_ls`, `bashls`, `yamlls`, `kotlin_lsp` |
| Formatters | `black`, `clang-format`, `goimports`, `isort`, `prettierd`, `shfmt`, `stylua`, `taplo`, `google-java-format`, `ktlint` |
| Native toolchains | `rustfmt` (Rust) — installed with its toolchain, not through Mason |

## Layouts

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
│   │   │                   #   opaque float surfaces, per-kind groups
│   │   ├── neovide.lua     # Neovide GUI settings
│   │   ├── pack.lua        # :PackUpdate / :PackList user commands
│   │   ├── lazy.lua        # native lazy loading — defers vim.pack.add until
│   │   │                   #   first require / command / keypress
│   │   └── reload.lua      # hot-reload of the core config layer
│   └── plugins/            # one file per plugin: vim.pack.add + setup
│       ├── init.lua        # loader — priority list, then alphabetical
│       ├── mini.lua        # most mini.* plugins (comment, icons, clue, ...)
│       ├── mason.lua       # mason + LSP-name bridge + tool installer (deferred)
│       ├── lspconfig.lua   # nvim-lspconfig (eager — base configs for vim.lsp)
│       ├── noice.lua       # floating cmdline / messages / popupmenu UI
│       ├── sessions.lua    # mini.sessions (named global sessions, deferred)
│       ├── statusline.lua  # mini.statusline (custom content)
│       └── ...             # bento, conform, fzf, todo-comments, toggleterm,
│                           #   tokyonight, treesitter
├── snippets/               # VS Code-format snippet collections
│   ├── c.json
│   ├── cpp.json
│   └── python.json
├── scripts/
│   ├── bootstrap-windows.ps1 # Windows system prerequisites
│   ├── screen-probe.ps1      # window/screenshot probing helper
│   └── versions.sh           # pinned versions/checksums for the bootstrap
├── .githooks/pre-commit    # auto-formats staged Lua files via StyLua
├── nvim-pack-lock.json     # vim.pack plugin revision lock
└── .stylua.toml            # StyLua formatter config
```

Each file under `lua/plugins/` is self-contained — it carries its own
`vim.pack.add` alongside its setup — and `lua/plugins/init.lua` loads them
all automatically (a short priority list first, then alphabetically). Adding
or removing a plugin is just adding or removing one file. Low-frequency
plugins (fzf-lua, toggleterm, bento, conform, mini.sessions, mini.jump2d,
and the Mason stack) defer their `vim.pack.add` through `config/lazy.lua`:
the first use — a `require` from a keymap callback, a `:Mason*` command, or
the `;` key — pulls the plugin in, while always-on UI stays eager.
`:PackUpdate` loads everything deferred first, so updates and `:PackList`
cover all plugins. Per-server LSP configs live as inline tables in
`lua/config/lsp.lua`, alongside the diagnostic display, native completion
activation, and the LSP keymaps.

## Keymap Groups

Leader = `<Space>`. Press `<Space>`, `[`, `]` or `s`; `mini.clue` displays the
available groups and actions after a short delay. Existing mapping
descriptions provide action hints, while explicit clues label the mnemonic
`<leader>` groups below.

| Prefix | Group | Examples |
|--------|-------|----------|
| `<leader>p` | Package management | `pm` Mason UI / `pu` plugin update / `pU` Mason tools update / `pl` plugin list / `pi` install |
| `<leader>s` | Splits | `ss` horizontal / `sv` vertical / `sc` close / `so` close others |
| `<leader>f` | Find | `ff` files / `fc` config / `fr` registers / `fh` help / `ft` TODO / `fk` keymaps / `fn` notifications; `fg` grep project / `fG` live grep / `fW` word under cursor |
| `<leader>b` | Buffers | `bn` next / `bp` previous / `bd` delete (`;` opens bento directly) |
| `<leader>l` | Languages | `lf` format / `lD` diagnostic details; LSP: `ld` definition / `lh` hover / `lR` references / `lr` rename / `la` code actions / `li` implementation / `ls` document symbols / `lS` workspace symbols / `lI` signature help |
| `<leader>c` | Config | `ce` edit / `cr` reload |
| `<leader>e` | File explorer | opens mini.files (Miller columns) |
| `<leader>S` | Sessions | `Ss` save / `Sl` load / `Sd` delete |
| `<leader>t` | Terminal | `th` horizontal / `tv` vertical / `tf` float / `tg` lazygit / `tp` ipython (`<F2>` toggles the float from normal and insert mode; in terminal mode it toggles the terminal under the cursor) |
| `<leader>u` | Toggles | `uw` wrap / `ui` inlay hints / `uc` completion autotrigger |

Direct keys:

- `<C-s>` save; `<leader>q` quit; `<leader>Q` quit all.
- Search: `*` searches the word under the cursor without jumping,
  `<Esc><Esc>` clears the search highlight, `n`/`N` jump and center the next
  result, `<C-d>`/`<C-u>` scroll half pages and center.
- Windows: native `<C-w>` navigation; `<C-Up>`/`<C-Down>`/`<C-Left>`/
  `<C-Right>` resize the current window.
- Motion and text: `f` jumps within the current line and `F` across the whole
  window (mini.jump2d single-character prompt, replacing the built-in motions); `gc`/`gcc`/`<C-/>`
  toggle comments; `]t`/`[t` jump between TODOs.

Diagnostic navigation uses `]d` / `[d` (and `]D` / `[D` for first/last), plus
`]b`/`[b` buffers, `]w`/`[w` windows, `]q`/`[q` quickfix/location, `]f`/`[f`
files, `]o`/`[o` oldfiles, `]u`/`[u` undo and more — all provided by
mini.bracketed; there are no duplicate `<leader>ln` / `<leader>lp` aliases.
LSP actions are global and use Neovim's built-in "no client attached" feedback
outside LSP buffers.

### Completion and snippets

- LSP completion opens automatically while typing: every printable ASCII
  keystroke requests completion from an `InsertCharPre` autocmd (the
  documented native alternative to extending triggerCharacters); multi-byte
  IME input never triggers. Use `<C-Space>` for a manual request. The popup
  never auto-selects or auto-inserts: move with `<C-n>`/`<C-p>`, accept with
  `<C-y>`. `<Tab>` does not accept — it closes the menu and keeps its usual
  indentation behavior. `<leader>uc` turns the every-keystroke autotrigger
  off when it gets noisy; `<C-Space>` keeps working in both states.
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

## Highlights

| Feature | Description |
|---------|-------------|
| Built-in plugin management | No third-party plugin manager — plugins install via `vim.pack`. `:PackUpdate` opens the official review buffer (`:write` applies, `:quit` discards), `:PackList` lists installed plugins. |
| Simple plugin lifecycle | Every plugin file carries its own `vim.pack.add` + setup — eager for always-on UI, or deferred through `config/lazy.lua` until first use (`require` / command / keypress). Mason defers to the first `:Mason*` command or 1s after `VimEnter`, keeping its background tool check off the startup path. Bootstrap mode (`NVIM_BOOTSTRAP=1`) runs every loader immediately so headless installs never miss a plugin. |
| Styled floating UI | `noice.nvim` replaces the native cmdline and completion popupmenu with bordered floats (nui backend); messages and notifications render as noice's built-in unfocusable mini cards (no nvim-notify needed). |
| Buffer manager | `bento.nvim` (`;`) — floating buffer switcher with actions (open, delete, split, lock). |
| File explorer | `mini.files` — Miller-column navigation and manipulation, replaces netrw by default, uses mini.icons. |
| Fuzzy finding | `fzf-lua` — files, config, registers, help, TODOs, keymaps, and project grep. |
| Character jumping | `mini.jump2d` — `f` in the current line, `F` across the whole window (single-character prompt; replaces the built-in motions). |
| Terminals | `toggleterm.nvim` — horizontal / vertical / floating terminals, lazygit, ipython. |
| Native LSP completion | Neovim 0.12 native completion per attached client; opens on every printable character, never auto-selects. |
| Snippets | `mini.snippets` with the local C/C++/Python collections in `snippets/`; `<C-j>` expand, `<C-l>`/`<C-h>` fields, `<C-q>` stop; Markdown disables LSP completion only. |
| Key discovery | `mini.clue` — lightweight which-key for `<leader>`, `[`, `]`, `s` (surround), without a second overlapping hint UI. |
| Code formatting | `conform.nvim` on demand (`<leader>lf`); formatters via Mason; project config preferred (`.clang-format`, Prettier) with Google Style / built-in defaults as fallback; `rustfmt` comes from the Rust toolchain. |
| Syntax highlighting | tree-sitter — every configured parser enabled automatically per filetype, regex fallback otherwise. |
| Textobjects | `mini.ai` — arguments, function calls, quotes, brackets, tags, and more; custom `aF`/`iF` whole-function target backed by nvim-treesitter-textobjects captures; consecutive expansion (`in` → `in` → ...). |
| Bracket navigation | `mini.bracketed` — `]`/`[` for diagnostics, indentation, comments, quickfix, buffers, windows, and more; pausing after either prefix shows the targets via `mini.clue`. |
| Comment toggling | `mini.comment` — `gc` / `gcc` / `<C-/>`. |
| Surround editing | `mini.surround` — `sa` add, `sd` delete, `sr` replace (visual add is also `sa` on the selection). |
| Per-filetype indentation | 2 spaces web/scripting/markup, 4 spaces systems languages, tabs Go/Make; `.editorconfig` wins; C/C++/ObjC default to Google Style with a project `.clang-format` override. |
| Real config reload | `<leader>cr` reloads the core config layer (options, keymaps, autocmds, LSP, Neovide settings, pack commands): tracked keymaps re-created, owned commands rebuilt, modules re-required in startup order. Plugin-file changes still need a restart. |
| QoL autocmds | Highlight on yank; restore last cursor position. |
| TODO highlighting | `todo-comments.nvim` — TODO/FIX/HACK/WARN/NOTE highlighting and search. |
| Sessions | `mini.sessions` — named global sessions under the data directory (nothing written into projects); `<leader>Ss` save / `<leader>Sl` load / `<leader>Sd` delete; restored sessions auto-update on exit; `sessionoptions` pinned to buffer/window state, so no global options or mappings ever travel inside a session and no dead terminal buffers are restored. |
| Notifications | `noice.nvim` owns `vim.notify` and renders every notification as unfocusable floating cards (built-in mini backend, 5s lifetime); native messages (E-errors, warnings, echo output) route through the same history. `<leader>fn` opens noice's message-history picker (fzf-lua, full-message preview). |
| Statusline | `mini.statusline` with custom content — per-mode gradient hue, git branch after cwd, centered cursor position, no file size. |
| Visual aides | `mini.indentscope` indent guides, `mini.trailspace` trailing whitespace, `mini.move` line moves with `Alt+↑/↓`. |
| Robust defaults | Persistent undo, native system clipboard (`unnamedplus`), `termguicolors`, deterministic plugin/config load order. |

## Plugins

| Plugin | Purpose |
|--------|---------|
| [bento.nvim](https://github.com/serhez/bento.nvim) | Buffer manager |
| [conform.nvim](https://github.com/stevearc/conform.nvim) | Code formatting |
| [fzf-lua](https://github.com/ibhagwan/fzf-lua) | Fuzzy finding |
| [mason.nvim](https://github.com/mason-org/mason.nvim) | External tool package manager |
| [mason-lspconfig.nvim](https://github.com/mason-org/mason-lspconfig.nvim) | LSP server name → Mason package mapping (used by the tool installer) |
| [mason-tool-installer.nvim](https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim) | Formatter installation |
| [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | Native LSP defaults |
| [noice.nvim](https://github.com/folke/noice.nvim) | Floating cmdline / messages / popupmenu UI |
| [nui.nvim](https://github.com/MunifTanjim/nui.nvim) | UI component backend for noice |
| [mini.ai](https://github.com/nvim-mini/mini.ai) | Textobjects |
| [mini.bracketed](https://github.com/nvim-mini/mini.bracketed) | Bracket navigation |
| [mini.clue](https://github.com/nvim-mini/mini.clue) | Leader-key discovery and groups |
| [mini.comment](https://github.com/nvim-mini/mini.comment) | Comment toggling |
| [mini.files](https://github.com/nvim-mini/mini.files) | File explorer |
| [mini.git](https://github.com/nvim-mini/mini-git) | Git data for the statusline |
| [mini.icons](https://github.com/nvim-mini/mini.icons) | Icon provider |
| [mini.indentscope](https://github.com/nvim-mini/mini.indentscope) | Indent guides |
| [mini.jump2d](https://github.com/nvim-mini/mini.jump2d) | Character jumping (`f` / `F`) |
| [mini.move](https://github.com/nvim-mini/mini.move) | Move lines/selections |
| [mini.sessions](https://github.com/nvim-mini/mini.sessions) | Named global session persistence |
| [mini.snippets](https://github.com/nvim-mini/mini.snippets) | Local C/C++/Python snippet expansion |
| [mini.statusline](https://github.com/nvim-mini/mini.statusline) | Statusline |
| [mini.surround](https://github.com/nvim-mini/mini.surround) | Surround editing |
| [mini.trailspace](https://github.com/nvim-mini/mini.trailspace) | Trailing whitespace |
| [todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | TODO highlighting |
| [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) | Toggleable terminals (terminal / lazygit / ipython) |
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Colorscheme (moon) |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Syntax highlighting |
| [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) | Textobject capture queries (consumed by mini.ai; the plugin itself stays unloaded) |

## Installation

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

The bootstrap installs Neovim, Neovide, Git, Node.js LTS, Python 3.13, Go,
Rust, OpenJDK 21, LLVM, ripgrep, fzf, lazygit, 7-Zip, and the 0xProto Nerd
Font (download verified by SHA-256), repairs Neovide's missing `PATH` entry,
creates the `Ctrl+Alt+N` Start Menu shortcut, installs ipython via pip (the
`<leader>tp` REPL), and then synchronizes all Mason-managed LSP servers and
formatters headlessly (`NVIM_BOOTSTRAP=1` + `+MasonToolsInstallSync`). Any
unacceptable exit code aborts the run.

## Platform behavior

- **Clipboard** — native Windows provider via `win32yank.exe`, which Neovim's
  own Windows distribution bundles in its `bin` directory (no extra install);
  `clipboard = "unnamedplus"` (yank and paste go through the system clipboard).
- **Shell** — `cmd.exe` is pinned for `:!` / `system()` / filters so a Git
  Bash-launched nvim never feeds cmd-style flags into Bash.
- **Tool discovery** — right after the UI comes up the config checks WinGet
  package dirs (`%LOCALAPPDATA%\Microsoft\WinGet\Packages`) for `fzf` /
  `lazygit` / `rg` and prepends them to `PATH` when a stale Explorer/Neovide
  environment hides them.
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
                            "   (deferred plugins load first, so all update)
```

The bootstrap script installs every dependency it declares and fails fast on
any unacceptable exit code (winget exit codes and SHA-256 checksum
verification). If something is missing afterwards, `:checkhealth` names the
tool and the fix.

Headless acceptance scripts live in `scripts/smoke/` (lazy-loading stubs,
command stubs + `:ConfigReload` interaction, terminal spawn + key stubs).
Run them from the dev checkout (via the `nvim-config` junction):

```sh
NVIM_APPNAME=nvim-config nvim --headless -S scripts/smoke/lazy.lua
```

## Future Considerations

These upstream changes may affect this config in the near future:

- **bento.nvim v2** — Migrated to the v2 API on the `feat/v2` branch
  (2026-09): explicit key/action registration via `require("bento.api")`,
  the `main_keymap` option is gone (`register_expand_key(";")` +
  `register_last_buffer_key(";")` recreate it). The branch is unmerged and
  the repo dormant since 2026-05; the lock file pins the exact rev, so drift
  only enters through a deliberate `:PackUpdate`. Re-check before updating:
  if upstream merges v2 into main (or reshapes the API), the registration
  block in `lua/plugins/bento.lua` is the only thing to touch.
- **nvim-treesitter health** — The repository was archived on 2026-04-03 and
  **reopened on 2026-07-18**; it is actively maintained again (parser bumps
  land every few days). This config uses it solely as the parser + query
  installer — highlighting itself already runs on the built-in
  `vim.treesitter` API. The long-term native path is Neovim's planned
  `nvim-treeconfig` distribution ([neovim#39006](https://github.com/neovim/neovim/issues/39006),
  plus prebuilt artifacts in [#39007](https://github.com/neovim/neovim/issues/39007));
  migrating to it once it ships should be near-zero cost, so watch those
  issues rather than pre-migrating.
- **nvim-treesitter-textobjects** — Archived in the same 2026-04 wave and
  likewise reopened; query updates track parser changes. Consumed purely as
  query data by mini.ai's `F` target (the plugin's Lua code never loads).
  If maintenance ever stops again, vendoring the per-language
  `textobjects.scm` files into `after/queries/` is the documented fallback
  (see mini.ai's manual-query notes).
