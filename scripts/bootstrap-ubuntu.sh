#!/usr/bin/env bash
#
# Ubuntu 24.04 system prerequisites for this Neovim config (this machine only:
# x86_64, snap, kitty, no Neovide). Prepares the system layer and then hands off
# to the config itself: Mason owns the LSP servers and formatters.
#
#   ./scripts/bootstrap-ubuntu.sh
#
# Pinned download versions are inlined below.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname -- "$SCRIPT_DIR")"

BIN_DIR="$HOME/.local/bin"
FONT_DIR="$HOME/.local/share/fonts/0xProtoNerdFont"

LAZYGIT_VERSION="0.65.1"
TREE_SITTER_VERSION="0.27.0"
NERD_FONTS_VERSION="3.5.0"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fetch() { # <url> <dest>
    curl -fsSL --retry 3 --connect-timeout 15 -o "$2" "$1"
}

# ── 1. System packages ───────────────────────────────────────────────────────
# build-essential supplies cc for tree-sitter parsers; xclip is the X11
# clipboard provider behind clipboard=unnamedplus; python3-venv is what Mason's
# pypi provider needs to build its isolated install environments — without it
# every pypi-hosted tool (black, clang-format, isort) fails with "ensurepip is
# not available". ipython3 is the <leader>tp REPL; Ubuntu ships it as
# /usr/bin/ipython3, so a plain `ipython` shim is added below.
info "installing system packages (sudo required)"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    fzf \
    git \
    ipython3 \
    nodejs \
    npm \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    unzip \
    xclip

if ! have ipython && have ipython3; then
    mkdir -p "$BIN_DIR"
    ln -sfn "$(command -v ipython3)" "$BIN_DIR/ipython"
    info "linked $BIN_DIR/ipython -> $(command -v ipython3)"
fi

# ── 2. Neovim ────────────────────────────────────────────────────────────────
# vim.pack and the native vim.lsp.completion APIs need 0.12+. Ubuntu's apt
# package is 0.9.5, so Neovim comes from the classic-confined snap.
if ! have nvim; then
    info "installing Neovim via snap"
    sudo snap install nvim --classic
fi
nvim_line=$(nvim --version | sed -n '1p')
info "Neovim ${nvim_line#NVIM }"

# ── 3. lazygit ───────────────────────────────────────────────────────────────
if ! have lazygit; then
    info "installing lazygit $LAZYGIT_VERSION"
    fetch "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
        "$TMP_DIR/lazygit.tar.gz"
    tar -xzf "$TMP_DIR/lazygit.tar.gz" -C "$TMP_DIR" lazygit
    install -Dm755 "$TMP_DIR/lazygit" "$BIN_DIR/lazygit"
    info "lazygit -> $BIN_DIR/lazygit"
fi

# ── 4. tree-sitter CLI ───────────────────────────────────────────────────────
# nvim-treesitter drives parser builds through this CLI — it runs
# `tree-sitter generate --abi <Neovim's ABI>` (so the generated parser always
# matches the runtime) and then `tree-sitter build`. Its README asks for the
# release binary, explicitly not the npm package.
if ! have tree-sitter; then
    info "installing tree-sitter CLI $TREE_SITTER_VERSION"
    fetch "https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/tree-sitter-linux-x64.gz" \
        "$TMP_DIR/tree-sitter.gz"
    gunzip -c "$TMP_DIR/tree-sitter.gz" >"$TMP_DIR/tree-sitter"
    install -Dm755 "$TMP_DIR/tree-sitter" "$BIN_DIR/tree-sitter"
    info "tree-sitter -> $BIN_DIR/tree-sitter"
fi

# ── 5. 0xProto Nerd Font ─────────────────────────────────────────────────────
# The fc-list output is compared as a string rather than piped into `grep -q`:
# grep exits at the first match and closes the pipe, so fc-list dies of SIGPIPE
# and `set -o pipefail` reports the successful match as a failure.
fonts=$(fc-list 2>/dev/null || true)
case "$fonts" in
    *"0xProto Nerd Font"*) info "0xProto Nerd Font already installed" ;;
    *)
        info "installing 0xProto Nerd Font $NERD_FONTS_VERSION"
        fetch "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/0xProto.zip" \
            "$TMP_DIR/0xProto.zip"
        mkdir -p "$FONT_DIR"
        unzip -oq "$TMP_DIR/0xProto.zip" -d "$FONT_DIR"
        fc-cache -f "$FONT_DIR" >/dev/null
        info "font -> $FONT_DIR"
        ;;
esac

# ── 6. git hooks ─────────────────────────────────────────────────────────────
git -C "$CONFIG_DIR" config core.hooksPath .githooks
info "git hooks path -> .githooks"

# ── 7. Plugin + Mason sync (headless) ────────────────────────────────────────
# Every plugin loads at startup now, so :MasonToolsInstallSync works from a
# plain headless run. Tree-sitter parsers compile on the first interactive
# start instead (the install is asynchronous and needs no help here).
info "installing plugins and syncing Mason tools (headless, this takes a while)"
# mason-tool-installer's debounce_hours=24 skips a run that follows a recent
# one, and its sync command honours that too — a re-run after a failed package
# would silently do nothing. Drop the marker so the sync always runs.
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason-tool-installer-debounce"
nvim --headless "+MasonToolsInstallSync" "+qa!"

printf '\n\033[1;32m✔ bootstrap complete\033[0m\n'
printf '  Start Neovim:        nvim\n'
printf '  Verify the install:  :checkhealth\n'
