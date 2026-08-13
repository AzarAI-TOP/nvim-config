#!/usr/bin/env bash
# 引导 Fedora / Ubuntu / Debian / WSL 的系统级依赖。
# Mason 在这些前置条件就绪后安装便携的 LSP/格式化器包。

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
    printf '安装系统包需要 sudo。\n' >&2
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
    # Fedora 是图形化 Linux 目标。即使引导在 DISPLAY 尚未导出的
    # TTY/SSH 会话中运行，也安装两种剪贴板提供者。
    if [[ $is_wsl == false && ${INSTALL_DESKTOP_DEPS:-1} == 1 ]]; then packages+=(wl-clipboard xclip); fi
    "${SUDO[@]}" dnf install -y "${packages[@]}"

    # Neovide 只在 Fedora 桌面上需要。某个 Fedora 发行版没有打包它时，
    # 不要让整个引导失败。
    if [[ $is_wsl == false && ${INSTALL_DESKTOP_DEPS:-1} == 1 ]]; then
        "${SUDO[@]}" dnf install -y neovide || printf 'Neovide 包不可用；请从 neovide.dev 安装。\n' >&2
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
    printf '不支持的包管理器。请按 README.md 手动安装所列工具。\n' >&2
    exit 1
fi

# vim.pack 需要 Neovim 0.12+。发行版包可能滞后，因此需要时把
# 固定版本官方发行包安装到带版本号的 ~/.local 目录下。
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
        *) printf '不支持的 Neovim 架构：%s\n' "$(uname -m)" >&2; exit 1 ;;
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
            printf '拒绝覆盖不完整且不受管路径：%s\n' "$install_dir" >&2
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

# Ubuntu 22.04 自带 fzf 0.29。发行版版本低于 fzf-lua 最低要求时
# 安装固定版本官方二进制，避免依赖 Ubuntu 过旧的 Go。
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
        *) printf '不支持的 fzf 架构：%s\n' "$(uname -m)" >&2; exit 1 ;;
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

# 让 Neovide 字体与 Windows 保持一致。字体只属于 Fedora 桌面；
# WSL 与无头 Ubuntu 通过宿主终端渲染。
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

# 同步安装 / 配置 Mason 管理的工具，让第一次交互式启动即完整可用，
# 而不是在后台下载包。
python3 -c 'import venv'
NVIM_BOOTSTRAP=1 nvim --headless "+MasonToolsInstallSync" "+qa!"
printf 'Linux 引导完成。在 Neovim 中运行 :checkhealth nvim_config。\n'
# shellcheck disable=SC2016 # $HOME/$PATH 文本是字面建议，不是展开
printf '让未来的 shell 生效，请确保 profile 包含：export PATH="$HOME/.local/bin:$PATH"\n'
