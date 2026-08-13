# Git Hooks

This directory contains version-controlled git hooks.

## Current hooks

- **pre-commit** — Formats staged `.lua` files with [StyLua](https://github.com/JohnnyMorganz/StyLua)
  using the project's `.stylua.toml` settings (4-space indent, 120 column width).

  The hook is **fail-closed**: the commit is aborted when StyLua cannot be
  found (PATH, Mason's package directory, or Mason's bin directory are all
  searched), when formatting fails, or when the post-format `stylua --check`
  fails. An unformattable commit is a failed commit — there is no silent
  skip path. Partially staged Lua files are refused as well.

## Setup

The hooks directory is configured automatically via:

```sh
git config core.hooksPath .githooks
```

If you clone this repo fresh, run that command (or the hooks won't fire).
To bypass hooks on a specific commit: `git commit --no-verify`.
