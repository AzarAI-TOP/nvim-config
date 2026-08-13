# nvim-config

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
│   │   ├── lsp_completion.lua  # native LSP completion activation
│   │   ├── neovide.lua      # shared Windows/Fedora Neovide settings
│   │   ├── platform.lua     # Windows/Linux/WSL/SSH detection
│   │   └── tools.lua        # shared LSP/formatter/system-tool inventory
│   ├── nvim_config/
│   │   └── health.lua       # :checkhealth nvim_config
│   ├── lsp/                 # one file per server, auto-loaded by config/lsp.lua
│   │   └── <server>.lua     # gopls, clangd, pyright, lua_ls, ...
│   └── plugins/             # one file per plugin: vim.pack.add + setup
│       ├── init.lua         # loader — priority list, then alphabetical
│       └── <name>.lua       # mason, tokyonight, fzf, mini-*, conform, ...
├── scripts/
│   ├── bootstrap-linux.sh   # Fedora/Ubuntu/WSL system prerequisites
│   ├── bootstrap-windows.ps1 # Windows system prerequisites
│   ├── test-config.sh       # headless test suite (bash)
│   └── test-config.ps1      # headless test suite (PowerShell)
├── tests/                   # headless startup/config/platform checks
├── .githooks/pre-commit     # auto-formats staged Lua files via StyLua
└── .stylua.toml             # StyLua formatter config
```

Each file under `lua/plugins/` is self-contained — it carries its own
`vim.pack.add` alongside its setup — and `lua/plugins/init.lua` loads them all
automatically (a short priority list first, then alphabetically). Adding or
removing a plugin is just adding or removing one file. Per-server LSP configs
live in `lua/lsp/<server>.lua` and are auto-loaded by `lua/config/lsp.lua`.

## Highlights

- **No third-party plugin manager** — plugins are installed via
  Neovim's built-in `vim.pack`; update with `:PackUpdate` (opens the official
  vim.pack review buffer — `:write` applies, `:quit` discards), list them with
  `:PackList`.
- **Buffer manager** — `bento.nvim` (`<leader>bb`) provides a floating buffer switcher
  with actions (open, delete, split, lock).
- **File explorer** — `mini.files` uses Miller columns for navigating and
  manipulating the file system. Replaces netrw by default.
- **Fuzzy finding** — `fzf-lua` for files (`<leader>ff`), config (`<leader>fc`),
  registers (`<leader>fr`), help (`<leader>fh`).
- **Native LSP completion + snippets** — Neovim 0.12 completion is enabled
  per attached client with automatic trigger-character support. `mini.snippets`
  loads the local C, C++, and Python collections from `snippets/`; type a prefix
  and press `<C-j>` to expand, then `<C-l>` / `<C-h>` to move between fields and
  `<C-c>` to stop the session.
  Markdown disables LSP completion to keep prose input immediate, while snippet expansion remains available.
- **Simple plugin lifecycle** — every plugin registers its own
  `vim.pack.add` and setup; Mason sets up synchronously at startup (registry
  and command registration only — tool installs happen after startup via the
  configured `run_on_start`). Bootstrap mode (`NVIM_BOOTSTRAP=1`) keeps the
  automatic check disabled so `+MasonToolsInstallSync` runs eagerly and
  headless runs never hit the network. Tokyo Night prepares on
  `ColorSchemePre`; TODO comments initialize on the first opened file.
- **Key discovery** — `mini.clue` describes the `<leader>b/c/f/l/p/s/t/w`
  groups without adding a second overlapping which-key UI.
- **Code formatting** — `conform.nvim` formats on demand (`<leader>lf`). Mason
  installs portable formatters automatically; `gofmt` and `rustfmt` come from
  their native Go/Rust toolchains. Java uses `google-java-format`, Kotlin uses
  `ktlint`, shell uses four spaces, C/C++ prefers the project `.clang-format`
  (Google Style only as fallback outside any configured project), and
  prettierd prefers project configuration while falling back to Prettier's
  built-in defaults when no project configuration exists.
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
  4 spaces for systems languages, tabs for Go/Make. Project `.editorconfig`
  values (full property and glob support via the runtime module) take
  precedence over these defaults.
- **Real config reload** — `<leader>cr` reloads the core config layer
  (options, keymaps, autocmds, LSP, Neovide settings, pack commands) for
  real: tracked keymaps are re-created, owned commands rebuilt, config
  modules re-required in startup order. Plugin-file changes (setup options,
  parsers, colorscheme style) still require a restart.
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
| [mini.snippets](https://github.com/nvim-mini/mini.snippets) | Local C/C++/Python snippet expansion |
| [mini.clue](https://github.com/nvim-mini/mini.clue) | Leader-key discovery and groups |
| [mini.trailspace](https://github.com/nvim-mini/mini.trailspace) | Trailing whitespace |
| [todo-comments.nvim](https://github.com/folke/todo-comments.nvim) | TODO highlighting |
| [tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Colorscheme (moon) |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Syntax highlighting |

## Install

### Windows

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
Java, LLVM, fzf, ripgrep, 7-Zip, and the 0xProto Nerd Font before synchronizing
all Mason-managed LSP servers and formatters.

### Fedora / Ubuntu / WSL

```sh
if command -v dnf >/dev/null; then sudo dnf install -y git curl; else sudo apt-get update && sudo apt-get install -y git curl; fi
git clone https://github.com/AzarAI-TOP/nvim-config "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
cd "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
git config core.hooksPath .githooks
bash scripts/bootstrap-linux.sh
```

The Linux bootstrap script:

- installs `git`, `curl`, compilers, Node, Go, Rust, Java, `fzf`, and `ripgrep`;
- installs Neovim under `~/.local` when the distro version is older than 0.12;
- installs both `wl-clipboard` and `xclip` for Fedora desktop, even when run
  from TTY/SSH; set `INSTALL_DESKTOP_DEPS=0` for a headless Fedora host;
- replaces distro `fzf` with a pinned, checksum-verified user-local release
  when it is older than the fzf-lua minimum (0.36);
- installs 0xProto Nerd Font on Fedora desktop (disable with
  `INSTALL_0XPROTO_FONT=0`);
- runs Mason's synchronous LSP server and formatter installation.

Ensure `~/.local/bin` is in your shell `PATH` after bootstrap.

## Platform behavior

| Environment | UI | Clipboard | Shell |
|-------------|----|-----------|-------|
| Windows | terminal / Neovide | native Windows provider | `cmd.exe` pinned for `:!` compatibility |
| Fedora desktop | terminal / Neovide | `wl-clipboard` (Wayland) or `xclip` (X11) | inherited user shell |
| WSL | terminal | `<leader>y` copies through OSC52; ordinary `p` stays internal | inherited Linux shell |
| Ubuntu over SSH | terminal | `<leader>y` copies through OSC52; ordinary `p` stays internal | inherited Linux shell |

OSC52 copy works in modern terminals such as Windows Terminal, WezTerm, Kitty,
and recent GNOME Terminal. Clipboard *read* may require explicit terminal
permission; normal terminal paste remains available regardless.

Neovide uses 0xProto Nerd Font at 13pt on Windows and Fedora. Windows-only title
bar and rounded-corner settings are not applied on Linux.

### Launching Neovide

On Windows, press `Ctrl+Alt+N` to launch Neovide via the Start Menu shortcut
(installed automatically by the bootstrap). Alternatively, run `neovide` from
PowerShell after the bootstrap adds it to your user `PATH`, or find "Neovide"
in the Start Menu.

On Fedora, launch `neovide` from a terminal or your application launcher.

IME auto-toggles for Chinese input: on in Insert mode and `/` / `?` search,
off in Normal mode and `:` commands.

## Verification

Run the isolated headless suite from the repository root. The wrapper copies
the working tree into a disposable XDG directory, disables background tool
downloads, and removes it afterwards.

```sh
bash scripts/test-config.sh
```

On Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-config.ps1
```

Set `TEST_DATA_HOME` to a persistent directory to reuse the already-downloaded
plugin install across runs (a fresh data dir makes `vim.pack` download all 21
plugins every time):

```sh
TEST_DATA_HOME="$HOME/.cache/nvim-config-test-data" bash scripts/test-config.sh
```

Inside Neovim, run `:checkhealth nvim_config` for platform-specific system-tool,
clipboard, and toolchain diagnostics. `:checkhealth` provides the full plugin
and provider report.

The `ubuntu-mason-first-boot` CI job additionally runs a real bootstrap in a
disposable environment, attaches representative LSP servers (lua_ls, pyright,
clangd, bashls), and executes every configured formatter against fixture
content — the same checks run locally by
`tests/check_first_boot_runtime.lua` after a bootstrap.

## Verification tiers

- **Ubuntu first boot (CI, every push)** — full bootstrap in a disposable
  environment: every Mason LSP server maps to an installed package, every
  formatter resolves to an executable, representative servers attach, and all
  configured formatters run against fixture content (including
  gofmt/goimports, rustfmt, and a project-`.clang-format` precedence check).
- **Windows bootstrap (CI, every push)** — control-flow logic tests with fake
  executors (never touches real installers, PATH, or the registry), on
  PowerShell 5.1 and 7, plus PSScriptAnalyzer.
- **Windows first boot (manual, `workflow_dispatch`)** — real Mason install
  and first-boot runtime checks on native Windows (shims, `.CMD` resolution).
- **Lint gates (CI, every push)** — StyLua `--check`, `bash -n`, ShellCheck,
  `git diff --check`, and a workflow-vs-`versions.sh` drift check.
- **Manual tier** — Fedora desktop Wayland/X11 clipboard, WSL/SSH OSC52,
  Neovide GUI/IME: covered by platform-detection unit tests and
  `:checkhealth`, verified by hand on real sessions.

## Key map groups

Press `<Space>` and continue with a group prefix; `mini.clue` displays the
available actions after a short delay.

| Prefix | Group | Examples |
|--------|-------|----------|
| `<leader>p` | Package management | `pm` Mason UI / `pu` plugin update / `pU` Mason tools update / `pp` plugin list / `pi` install |
| `<leader>s` | Splits | create/close/keep split |
| `<leader>f` | Find | files/config/registers/help/TODO |
| `<leader>b` | Buffers | next/previous/delete/bento |
| `<leader>l` | Languages | format/LSP/diagnostic details |
| `<leader>c` | Config | edit/reload config |
| `<leader>t` | Toggles | wrap |
| `<leader>w` | Windows | forwards to native `<C-w>` commands |

Diagnostics deliberately use only `]d` and `[d` for next/previous navigation;
there are no duplicate `<leader>ln` / `<leader>lp` aliases. LSP actions are
global and use Neovim's built-in "no client attached" feedback outside LSP
buffers.

## Completion and snippets

- LSP completion opens automatically for server trigger characters. Use
  `<C-Space>`/`<C-x><C-o>` for manual completion and `<C-y>` to accept an item.
- Snippets: type `main`, `for`, `if`, `def`, etc., then press `<C-j>` to expand.
  During a snippet session, use `<C-l>` and `<C-h>` to move forward/backward,
  and `<C-c>` to stop the session.
- Snippet files live in `snippets/c.json`, `snippets/cpp.json`, and
  `snippets/python.json`; they use VS Code/LSP snippet JSON syntax. Loaders
  cache file contents, so after editing a snippet file restart Neovim or run
  `MiniSnippets.setup(MiniSnippets.config)` to clear the cached loaders.
- Markdown disables LSP completion to keep prose input immediate, but retains
  the snippet mechanism and its `<C-j>` mapping. No `markdown.json` snippet
  file is bundled; add one under `snippets/` to use snippets in Markdown.

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
