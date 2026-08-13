#!/usr/bin/env bash
# Run the Conform/prettierd runtime probe (tests/check_formatter_runtime.lua)
# against a bootstrapped Mason environment.
#
# This probe is intentionally NOT part of the ordinary offline suite
# (scripts/test-config.sh): it needs a real prettierd executable, which only
# exists after Mason has installed it (local bootstrap or the Linux first-boot
# CI job).
#
# Usage:
#   bash scripts/run-formatter-runtime-probe.sh
#   NVIM_FORMATTER_RUNTIME_MUTATION=1 bash scripts/run-formatter-runtime-probe.sh
#
# Environment:
#   PROBE_CONFIG_HOME  config root under test (default: disposable copy of repo)
#   PROBE_DATA_HOME    data root containing the bootstrapped Mason install
#                      (default: this machine's real nvim data dir)
#   NVIM_FORMATTER_RUNTIME_MUTATION=1
#                      corrupt the prettierd command in memory; every positive
#                      probe must then fail (RED check; used by CI).
#   PROBE_SCRIPT       probe file relative to the config root
#                      (default: tests/check_formatter_runtime.lua)
#
# The nvim run is bounded by an external 120s timeout.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# --- data root (must contain a bootstrapped Mason install) -------------------
if [[ -n "${PROBE_DATA_HOME:-}" ]]; then
    data_home="$PROBE_DATA_HOME"
elif [[ ${OS:-} == Windows_NT ]]; then
    data_home="${LOCALAPPDATA:-$HOME/AppData/Local}/nvim-data"
else
    data_home="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
fi
mason_bin="$data_home/mason/bin"
if [[ ! -e "$mason_bin/prettierd.cmd" && ! -e "$mason_bin/prettierd" ]]; then
    echo "run-formatter-runtime-probe: prettierd not found under $mason_bin (run the bootstrap first)" >&2
    exit 2
fi

# --- config root (isolated copy of the development config) -------------------
tmp_config=""
if [[ -n "${PROBE_CONFIG_HOME:-}" ]]; then
    config_home="$PROBE_CONFIG_HOME"
else
    tmp_config=$(mktemp -d)
    mkdir -p "$tmp_config/nvim"
    tar --exclude=.git -C "$repo_root" -cf - . | tar -C "$tmp_config/nvim" -xf -
    config_home="$tmp_config/nvim"
fi

native_path() {
    if [[ ${OS:-} == Windows_NT ]] && command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s\n' "$1"
    fi
}

cleanup() {
    # prettierd keeps a daemon whose cwd is the run directory, which would pin
    # it and make rm fail with "Device or resource busy". Stop daemons first
    # (bounded so a stuck daemon cannot hang the wrapper), then remove the copy.
    if [[ -e "$mason_bin/prettierd.cmd" ]]; then
        timeout 30 "$mason_bin/prettierd.cmd" stop >/dev/null 2>&1 || true
    elif [[ -e "$mason_bin/prettierd" ]]; then
        timeout 30 "$mason_bin/prettierd" stop >/dev/null 2>&1 || true
    fi
    if [[ -n "$tmp_config" ]]; then
        # The shell's cwd is inside $tmp_config (the probe runs from the config
        # copy); leave it before rm so the tree is not pinned. Retry deletion
        # in an explicit loop. If it still fails, warn — but never let the
        # cleanup outcome replace the captured probe exit status.
        cd / 2>/dev/null || cd "$repo_root" || true
        local attempt=0
        while ! rm -rf -- "$tmp_config"; do
            attempt=$((attempt + 1))
            if (( attempt >= 3 )); then
                echo "run-formatter-runtime-probe: WARNING: could not remove temp config $tmp_config" >&2
                return 0
            fi
            sleep 2
        done
        tmp_config=""
    fi
}
trap cleanup EXIT

export XDG_CONFIG_HOME="$(native_path "$(dirname "$config_home")")"
export XDG_DATA_HOME="$(native_path "$data_home")"
export XDG_STATE_HOME="$(native_path "$(dirname "$config_home")/state")"
export XDG_CACHE_HOME="$(native_path "$(dirname "$config_home")/cache")"
export NVIM_CONFIG_TEST=1
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=core.longpaths
export GIT_CONFIG_VALUE_0=true
# Make the bootstrapped Mason bin resolvable regardless of Mason's own PATH hook.
export PATH="$mason_bin:$PATH"

mkdir -p "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

cd "$config_home"
probe_script="${PROBE_SCRIPT:-tests/check_formatter_runtime.lua}"
echo "run-formatter-runtime-probe: config=$config_home data=$data_home probe=$probe_script"
# --kill-after=10 forces nvim down even if it ignores SIGTERM (e.g. stuck
# mid vim.pack install), so the external bound is hard.
probe_status=0
timeout --kill-after=10 120 nvim --headless init.lua "+lua dofile(vim.fs.joinpath(vim.fn.getcwd(), '$probe_script'))" || probe_status=$?

# Preserve the probe's exit status explicitly: cleanup runs afterwards, but its
# outcome (a warning at worst) must never replace the probe result.
cleanup
exit "$probe_status"
