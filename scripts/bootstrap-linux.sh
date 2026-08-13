#!/usr/bin/env bash
# Bootstrap system-level dependencies for Fedora, Ubuntu, Debian, and WSL.
# Mason installs the portable LSP/formatter packages after these prerequisites.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source-path=scripts
# shellcheck source=versions.sh
source "$script_dir/versions.sh"

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
        python3 python3-pip
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
        python3 python3-venv python3-pip
    )
    if [[ $is_wsl == false && ${INSTALL_DESKTOP_DEPS:-0} == 1 ]]; then packages+=(wl-clipboard xclip); fi
    "${SUDO[@]}" apt-get update
    "${SUDO[@]}" apt-get install -y "${packages[@]}"
else
    printf 'Unsupported package manager. Install the tools listed in README.md manually.\n' >&2
    exit 1
fi

# vim.pack requires Neovim 0.12+. Distro packages may lag, so install the pinned
# official release under a versioned ~/.local directory when needed.
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
        x86_64) nvim_arch=x86_64; nvim_sha256=$NVIM_SHA256_X86_64 ;;
        aarch64|arm64) nvim_arch=arm64; nvim_sha256=$NVIM_SHA256_ARM64 ;;
        *) printf 'Unsupported Neovim architecture: %s\n' "$(uname -m)" >&2; exit 1 ;;
    esac

    tmp_dir=$(mktemp -d)
    cleanup_dirs+=("$tmp_dir")
    archive="nvim-linux-${nvim_arch}.tar.gz"
    curl -fL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${archive}" -o "$tmp_dir/$archive"
    printf '%s  %s\n' "$nvim_sha256" "$tmp_dir/$archive" | sha256sum -c -
    mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
    install_dir="$HOME/.local/opt/nvim-${NVIM_VERSION}"
    if [[ ! -x "$install_dir/bin/nvim" ]]; then
        if [[ -e $install_dir ]]; then
            printf 'Refusing to replace incomplete unmanaged path: %s\n' "$install_dir" >&2
            exit 1
        fi
        install_tmp="$HOME/.local/opt/.nvim-${NVIM_VERSION}.$$"
        cleanup_dirs+=("$install_tmp")
        mkdir -p "$install_tmp"
        tar -xzf "$tmp_dir/$archive" -C "$install_tmp" --strip-components=1
        test -x "$install_tmp/bin/nvim"
        mv "$install_tmp" "$install_dir"
    fi
    ln -sfn "$install_dir/bin/nvim" "$HOME/.local/bin/nvim"
fi

export PATH="$HOME/.local/bin:$PATH"

# Ubuntu 22.04 ships fzf 0.29. Install a pinned official binary when the distro
# version is below fzf-lua's minimum; this avoids relying on Ubuntu's old Go.
fzf_is_current=false
if command -v fzf >/dev/null 2>&1; then
    fzf_version=$(fzf --version | { IFS=' ' read -r version _; printf '%s' "$version"; })
    if [[ $(printf '%s\n' 0.36.0 "$fzf_version" | sort -V | command tail -n 1) == "$fzf_version" ]]; then
        fzf_is_current=true
    fi
fi
if [[ $fzf_is_current == false ]]; then
    case $(uname -m) in
        x86_64) fzf_arch=amd64; fzf_sha256=$FZF_SHA256_AMD64 ;;
        aarch64|arm64) fzf_arch=arm64; fzf_sha256=$FZF_SHA256_ARM64 ;;
        *) printf 'Unsupported fzf architecture: %s\n' "$(uname -m)" >&2; exit 1 ;;
    esac
    tmp_fzf=$(mktemp -d)
    cleanup_dirs+=("$tmp_fzf")
    fzf_archive="fzf-${FZF_VERSION}-linux_${fzf_arch}.tar.gz"
    curl -fL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/${fzf_archive}" -o "$tmp_fzf/$fzf_archive"
    printf '%s  %s\n' "$fzf_sha256" "$tmp_fzf/$fzf_archive" | sha256sum -c -
    tar -xzf "$tmp_fzf/$fzf_archive" -C "$tmp_fzf" fzf
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$tmp_fzf/fzf" "$HOME/.local/bin/.fzf.tmp.$$"
    mv -f "$HOME/.local/bin/.fzf.tmp.$$" "$HOME/.local/bin/fzf"
fi

# Keep the Neovide font identical to Windows. Fonts belong on the Fedora
# desktop only; WSL and headless Ubuntu render through the host terminal.
if [[ $is_fedora == true && $is_wsl == false && ${INSTALL_DESKTOP_DEPS:-1} == 1 && ${INSTALL_0XPROTO_FONT:-1} == 1 ]]; then
    font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/0xProtoNerdFont"
    if ! fc-list 2>/dev/null | command grep -qi '0xProto Nerd Font'; then
        tmp_font=$(mktemp -d)
        cleanup_dirs+=("$tmp_font")
        curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/0xProto.tar.xz" -o "$tmp_font/0xProto.tar.xz"
        printf '%s  %s\n' "$OXPROTO_SHA256_XZ" "$tmp_font/0xProto.tar.xz" | sha256sum -c -
        mkdir -p "$font_dir"
        tar -xJf "$tmp_font/0xProto.tar.xz" -C "$font_dir"
        fc-cache -f "$font_dir"
    fi
fi

# Install/configure Mason-managed tools synchronously so the first interactive
# launch is complete rather than downloading packages in the background.
python3 -c 'import venv'
NVIM_BOOTSTRAP=1 nvim --headless "+MasonToolsInstallSync" "+qa!"
printf 'Linux bootstrap complete. Run :checkhealth nvim_config inside Neovim.\n'
# shellcheck disable=SC2016 # the $HOME/$PATH text is literal advice, not expansion
printf 'For future shells, ensure your profile contains: export PATH="$HOME/.local/bin:$PATH"\n'
