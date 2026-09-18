<div align="center">

```
 ███╗   ██╗███████╗███╗   ██╗
 ████╗  ██║██╔════╝████╗  ██║
 ██╔██╗ ██║█████╗  ██╔██╗ ██║
 ██║╚██╗██║██╔══╝  ██║╚██╗██║
 ██║ ╚████║███████╗██║ ╚████║
 ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═══╝
```

**one repo · two machines · zero plugin managers**

`main` is nothing but this page — a router. The configs live in the branches.

</div>

---

## `$ git branch -a`

| branch | target | flavor | diet |
|---|---|---|---|
| [`windows`](../tree/windows) | Windows 10/11 | Neovide GUI | C/C++ · TS/JS · Python |
| [`ubuntu`](../tree/ubuntu) | Ubuntu 24.04 | kitty on X11 | Go · Rust · Kotlin/JVM · Python |

Same DNA, different diets. Each branch scopes itself to the toolchains
actually installed on its machine — the heavy compiled-language work
(`gopls` · `rust_analyzer` · `kotlin_lsp`) lives on `ubuntu`.

## `$ git checkout windows`

The Windows rig: Neovide with rounded corners, cursor VFX and IME
auto-switching, launched by `Ctrl+Alt+N` or the Start Menu. TokyoNight Moon
title bar, 0xProto at 13pt. Nine LSP servers and seven formatters, all
Mason-managed. A VimEnter probe re-scans the winget portable dirs, so fzf /
lazygit / rg never go missing after winget moves them.

```powershell
git clone -b windows https://github.com/AzarAI-TOP/nvim-config.git "$env:LOCALAPPDATA\nvim"
& "$env:LOCALAPPDATA\nvim\scripts\bootstrap-windows.ps1"
```

The bootstrap drives winget for the system layer (Git, Neovim, Neovide,
ripgrep, fzf, lazygit, Node LTS, Python), repairs Neovide's PATH entry,
installs the 0xProto Nerd Font, pins the `Ctrl+Alt+N` launcher — then
headlessly syncs every Mason package. Re-runnable; if something trips, re-run
it and read winget's own output.

## `$ git checkout ubuntu`

The Linux workhorse: Ubuntu 24.04, kitty on X11, Neovim from snap — because
apt still ships 0.9.5, which is not a version, it's a warning. Carries the
compiled-language stack (`gopls`, `rust_analyzer`, `kotlin_lsp`) on top of
the common set; lazygit and the tree-sitter CLI arrive as version-pinned
release binaries.

```bash
git clone -b ubuntu https://github.com/AzarAI-TOP/nvim-config.git ~/.config/nvim
~/.config/nvim/scripts/bootstrap-ubuntu.sh
```

`set -euo pipefail` — the script either finishes or tells you exactly where
it died, then hands off to Mason for the LSP/formatter layer.

## Shared DNA

Both branches are the same design, retargeted:

- **Neovim ≥ 0.12** — `vim.pack` is the plugin manager, native
  `vim.lsp.completion` is the completion engine. No lazy.nvim, no nvim-cmp,
  no glue code left to rot.
- **One file per plugin** under `lua/plugins/` — each carries its own
  `vim.pack.add` next to its setup. Delete the file, delete the plugin.
- **Everything loads at startup.** No lazy-loading layer, no hot reload —
  startup stays fast enough that the machinery isn't worth its weight.
- **mini.\* everywhere** — ai, bracketed, clue, comment, files, git, icons,
  indentscope, jump2d, move, sessions, snippets, statusline, surround,
  trailspace — plus fzf-lua, noice, toggleterm, todo-comments, tokyonight,
  nvim-treesitter.
- **`<Space>` is the leader**, and `mini.clue` is the manual: hold a prefix,
  read the popup.
- **Pinned** by `nvim-pack-lock.json`; a StyLua pre-commit hook refuses to
  let an unformatted diff through.

```console
$ nvim --version | grep -c apology
0
```

## Why branches, not one config

One Config To Rule Them All™ means `has('win32')` soup, options that only
half-apply, and a config that runs perfectly on no machine. Here a branch
*is* a machine profile: read `windows` and you're reading exactly what the
Windows box executes — nothing more. Shared commits travel between branches;
divergence is honest and shows up in `git log`.

The full story — keymap atlas, layout, machine-specific notes — lives in each
branch's own README. MIT licensed; the LICENSE travels with the config
branches.
