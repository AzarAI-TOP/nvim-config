#!/bin/sh
# Print "<screen_px> <window_px>" for the X terminal window given by $WINDOWID
# (kitty exports it). lua/plugins/statusline.lua turns those two widths into the
# narrow-layout threshold of the statusline, so the window is identified directly
# instead of by walking the process tree.
#
#   ./scripts/screen-probe.sh 62914574
#
# The monitor is selected by the window's position rather than by "primary":
# a laptop panel next to an external screen is routinely a different size, and
# measuring the wrong one skews the threshold by a third.

set -eu

win_id="${1:-${WINDOWID:-}}"

info=$(xwininfo -id "$win_id")

field() { # <label>
    printf '%s\n' "$info" | sed -n "s/^ *$1: *\(-\{0,1\}[0-9]\{1,\}\)$/\1/p" | sed -n '1p'
}

win_x=$(field "Absolute upper-left X")
win_y=$(field "Absolute upper-left Y")
win_w=$(field "Width")
win_h=$(field "Height")

# Compare the window's centre against each monitor's rectangle.
cx=$((win_x + win_w / 2))
cy=$((win_y + win_h / 2))

screen_px=""
fallback_px=""
while read -r name state rest; do
    [ "$state" = "connected" ] || continue
    # The geometry follows an optional "primary" token.
    case "$rest" in "primary "*) rest=${rest#primary } ;; esac
    geom=${rest%% *}
    width=${geom%%x*}
    tail_part=${geom#*x}
    height=${tail_part%%+*}
    offset_part=${tail_part#*+}
    mon_x=${offset_part%%+*}
    mon_y=${offset_part#*+}
    case "$width" in *[!0-9]* | "") continue ;; esac

    [ -n "$fallback_px" ] || fallback_px=$width

    if [ "$cx" -ge "$mon_x" ] && [ "$cx" -lt "$((mon_x + width))" ] &&
        [ "$cy" -ge "$mon_y" ] && [ "$cy" -lt "$((mon_y + height))" ]; then
        screen_px=$width
        break
    fi
done <<EOF
$(xrandr --current | grep ' connected')
EOF

# A window whose centre falls outside every monitor still measures the window
# itself correctly; the first connected monitor is the better reference.
screen_px=${screen_px:-$fallback_px}

echo "$screen_px $win_w"
