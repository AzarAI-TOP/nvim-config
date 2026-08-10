#!/usr/bin/env bash
# Download pinned Linux assets and verify their release SHA-256 digests.

set -euo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=versions.sh
source "$script_dir/versions.sh"

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

verify_asset() {
    local url=$1
    local sha256=$2
    local output=$3
    curl -fL "$url" -o "$output"
    printf '%s  %s\n' "$sha256" "$output" | sha256sum -c -
}

verify_asset \
    "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
    "$NVIM_SHA256_X86_64" \
    "$tmp_dir/nvim-linux-x86_64.tar.gz"
verify_asset \
    "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
    "$FZF_SHA256_AMD64" \
    "$tmp_dir/fzf-linux-amd64.tar.gz"
verify_asset \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/0xProto.tar.xz" \
    "$OXPROTO_SHA256" \
    "$tmp_dir/0xProto.tar.xz"

printf 'PINNED_ASSET_VERIFY_OK\n'
