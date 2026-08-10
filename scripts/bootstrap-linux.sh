#!/usr/bin/env bash
# Bootstrap system-level dependencies for Fedora, Ubuntu, Debian, and WSL.
# Mason installs the portable LSP/formatter packages after these prerequisites.

set -euo pipefail

cleanup_dirs=()
cleanup() {
    local dir
    for dir in "${cleanup_dirs[@]}"; do rm -rf -- "$dir"; done
}
trap cleanup EXIT

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    SUDO=()
elif command -v sudo >/dev/null 2>&1; then
    SUDO=(sudo)
else
    printf 'sudo is required to install system packages.\n' >&2
    exit 1
fi

is_wsl=false
if [[ -n ${WSL_DISTRO_NAME:-} || -n ${WSL_INTEROP:-} ]] || uname -r | tr '[:upper:]' '[:lower:]' | command grep -q microsoft; then
    is_wsl=true
fi

is_fedora=false
if command -v dnf >/dev/null 2>&1; then
    is_fedora=true
    packages=(
        git curl unzip xz tar make gcc gcc-c++ ripgrep fzf fontconfig
        nodejs npm golang rust cargo rustfmt clang-tools-extra java-latest-openjdk-headless
    )
    # Fedora is the graphical Linux target. Install both providers even when
    # bootstrap runs from a TTY/SSH session before DISPLAY is exported.
    if [[ $is_wsl == false && ${INSTALL_DESKTOP_DEPS:-1} == 1 ]]; then packages+=(wl-clipboard xclip); fi
    "${SUDO[@]}" dnf install -y "${packages[@]}"

    # Neovide is needed only on the Fedora desktop. Do not make the whole
    # bootstrap fail if a particular Fedora release does not package it.
    if [[ $is_wsl == false && ${INSTALL_DESKTOP_DEPS:-1} == 1 ]]; then
        "${SUDO[@]}" dnf install -y neovide || printf 'Neovide package unavailable; install it from neovide.dev.\n' >&2
    fi
elif command -v apt-get >/dev/null 2>&1; then
    packages=(
        git curl ca-certificates unzip xz-utils tar build-essential ripgrep fzf
        nodejs npm golang-go rustc cargo rustfmt clang-format default-jre-headless
    )
    if [[ $is_wsl == false && ${INSTALL_DESKTOP_DEPS:-0} == 1 ]]; then packages+=(wl-clipboard xclip); fi
    "${SUDO[@]}" apt-get update
    "${SUDO[@]}" apt-get install -y "${packages[@]}"
else
    printf 'Unsupported package manager. Install the tools listed in README.md manually.\n' >&2
    exit 1
fi

# vim.pack requires Neovim 0.12+. Distro packages may lag, so install the latest
# official release under ~/.local when the system version is too old.
needs_nvim=true
if command -v nvim >/dev/null 2>&1; then
    version_line=$(nvim --version | { IFS= read -r line; printf '%s' "$line"; })
    current_version=${version_line#NVIM v}
    if [[ $(printf '%s\n' 0.12.0 "$current_version" | sort -V | command tail -n 1) == "$current_version" ]]; then
        needs_nvim=false
    fi
fi

if [[ $needs_nvim == true ]]; then
    case $(uname -m) in
        x86_64) nvim_arch=x86_64 ;;
        aarch64|arm64) nvim_arch=arm64 ;;
        *) printf 'Unsupported Neovim architecture: %s\n' "$(uname -m)" >&2; exit 1 ;;
    esac

    tmp_dir=$(mktemp -d)
    cleanup_dirs+=("$tmp_dir")
    archive="nvim-linux-${nvim_arch}.tar.gz"
    curl -fL "https://github.com/neovim/neovim/releases/latest/download/${archive}" -o "$tmp_dir/$archive"
    tar -xzf "$tmp_dir/$archive" -C "$tmp_dir"
    mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
    rm -rf "$HOME/.local/opt/nvim"
    mv "$tmp_dir/nvim-linux-${nvim_arch}" "$HOME/.local/opt/nvim"
    ln -sfn "$HOME/.local/opt/nvim/bin/nvim" "$HOME/.local/bin/nvim"
fi

export PATH="$HOME/.local/bin:$PATH"

# Ubuntu 22.04 ships fzf 0.29, while fzf-lua requires >0.36. Build the current
# release with the installed Go toolchain when the distro package is too old.
fzf_is_current=false
if command -v fzf >/dev/null 2>&1; then
    fzf_version=$(fzf --version | { IFS=' ' read -r version _; printf '%s' "$version"; })
    if [[ $(printf '%s\n' 0.36.0 "$fzf_version" | sort -V | command tail -n 1) == "$fzf_version" ]]; then
        fzf_is_current=true
    fi
fi
if [[ $fzf_is_current == false ]]; then
    mkdir -p "$HOME/.local/bin"
    GOBIN="$HOME/.local/bin" go install github.com/junegunn/fzf@latest
fi

# Keep the Neovide font identical to Windows. Fonts belong on the Fedora
# desktop only; WSL and headless Ubuntu render through the host terminal.
if [[ $is_fedora == true && $is_wsl == false && ${INSTALL_DESKTOP_DEPS:-1} == 1 && ${INSTALL_0XPROTO_FONT:-1} == 1 ]]; then
    font_dir="$HOME/.local/share/fonts/0xProtoNerdFont"
    if ! fc-list 2>/dev/null | command grep -qi '0xProto Nerd Font'; then
        tmp_font=$(mktemp -d)
        cleanup_dirs+=("$tmp_font")
        curl -fL 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.tar.xz' -o "$tmp_font/0xProto.tar.xz"
        mkdir -p "$font_dir"
        tar -xJf "$tmp_font/0xProto.tar.xz" -C "$font_dir"
        fc-cache -f "$font_dir"
    fi
fi

# Install/configure Mason-managed tools synchronously so the first interactive
# launch is complete rather than downloading packages in the background.
nvim --headless "+MasonToolsInstallSync" "+qa!"
printf 'Linux bootstrap complete. Run :checkhealth nvim_config inside Neovim.\n'
