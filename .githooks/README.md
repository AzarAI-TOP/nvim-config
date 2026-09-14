# Git Hooks

This directory contains version-controlled git hooks.

## Current hooks

- **pre-commit** — Formats staged `.lua` files with [StyLua](https://github.com/JohnnyMorganz/StyLua)
  using the project's `.stylua.toml` settings (4-space indent, 120 column width).

  The hook is **fail-closed**: the commit is aborted when StyLua cannot be
  found (PATH and Mason's package directory under `~/.local/share/nvim/mason`
  are both searched), when formatting
  fails, or when the post-format `stylua --check` fails. An unformattable
  commit is a failed commit — there is no silent skip path. Partially staged
  Lua files are refused as well.

## Setup

Configure the hooks directory once after cloning:

```sh
git config core.hooksPath .githooks
```

`scripts/bootstrap-ubuntu.sh` runs that command for you.
To bypass hooks on a specific commit: `git commit --no-verify`.
