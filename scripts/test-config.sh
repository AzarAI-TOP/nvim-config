#!/usr/bin/env bash
# Run the config suite from a disposable XDG environment.

set -euo pipefail

# The suite runs in test mode (NVIM_CONFIG_TEST=1): Mason setup stays
# synchronous but the automatic install check is disabled, so headless runs
# never hit the network.
unset NVIM_BOOTSTRAP 2>/dev/null || true

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
cleanup() { rm -rf -- "$tmp_dir"; }
trap cleanup EXIT

mkdir -p "$tmp_dir/xdg/nvim" "$tmp_dir/data" "$tmp_dir/state" "$tmp_dir/cache"
tar --exclude=.git -C "$repo_root" -cf - . | tar -C "$tmp_dir/xdg/nvim" -xf -

# TEST_DATA_HOME reuses a persistent plugin install (vim.pack downloads all
# 21 plugins on a fresh data dir, which dominates suite runtime). The suite
# never installs Mason packages, so a shared data dir is safe.
if [[ -n "${TEST_DATA_HOME:-}" ]]; then
    mkdir -p "$TEST_DATA_HOME"
    data_home="$TEST_DATA_HOME"
else
    data_home="$tmp_dir/data"
fi

native_path() {
    if [[ ${OS:-} == Windows_NT ]] && command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s\n' "$1"
    fi
}

native_xdg_config=$(native_path "$tmp_dir/xdg")
native_xdg_data=$(native_path "$data_home")
native_xdg_state=$(native_path "$tmp_dir/state")
native_xdg_cache=$(native_path "$tmp_dir/cache")
export XDG_CONFIG_HOME="$native_xdg_config"
export XDG_DATA_HOME="$native_xdg_data"
export XDG_STATE_HOME="$native_xdg_state"
export XDG_CACHE_HOME="$native_xdg_cache"
export NVIM_CONFIG_TEST=1
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=core.longpaths
export GIT_CONFIG_VALUE_0=true

cd "$tmp_dir/xdg/nvim"
output=$(nvim --headless "+lua dofile(vim.fs.joinpath(vim.fn.getcwd(), 'tests', 'run.lua'))" 2>&1)
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q 'CONFIG_TEST_SUITE_OK'
