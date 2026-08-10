#!/usr/bin/env bash
# Run the config suite from a disposable XDG environment.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
cleanup() { rm -rf -- "$tmp_dir"; }
trap cleanup EXIT

mkdir -p "$tmp_dir/xdg/nvim" "$tmp_dir/data" "$tmp_dir/state" "$tmp_dir/cache"
tar --exclude=.git -C "$repo_root" -cf - . | tar -C "$tmp_dir/xdg/nvim" -xf -

native_path() {
    if [[ ${OS:-} == Windows_NT ]] && command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s\n' "$1"
    fi
}

export XDG_CONFIG_HOME="$(native_path "$tmp_dir/xdg")"
export XDG_DATA_HOME="$(native_path "$tmp_dir/data")"
export XDG_STATE_HOME="$(native_path "$tmp_dir/state")"
export XDG_CACHE_HOME="$(native_path "$tmp_dir/cache")"
export NVIM_CONFIG_TEST=1
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=core.longpaths
export GIT_CONFIG_VALUE_0=true

cd "$tmp_dir/xdg/nvim"
nvim --headless "+lua dofile(vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'run.lua'))"
