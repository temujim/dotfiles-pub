#!/usr/bin/env bash
set -euo pipefail

out_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
out_file="$out_dir/terminal_geometry.env"
mkdir -p "$out_dir"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Terminal.app exposes window bounds plus row/column counts via AppleScript.
# Keep this best-effort: if macOS automation is denied, write timestamp only.
geom="$(/usr/bin/osascript <<'OSA' 2>/dev/null || true
tell application "Terminal"
  if exists window 1 then
    set b to bounds of window 1
    set r to number of rows of window 1
    set c to number of columns of window 1
    return (item 1 of b as text) & "," & (item 2 of b as text) & "," & (item 3 of b as text) & "," & (item 4 of b as text) & "," & (r as text) & "," & (c as text)
  end if
end tell
OSA
)"

{
  printf 'SAVED_AT=%q\n' "$ts"
  if [ -n "$geom" ]; then
    IFS=',' read -r left top right bottom rows cols <<< "$geom"
    printf 'BOUNDS_LEFT=%q\n' "$left"
    printf 'BOUNDS_TOP=%q\n' "$top"
    printf 'BOUNDS_RIGHT=%q\n' "$right"
    printf 'BOUNDS_BOTTOM=%q\n' "$bottom"
    printf 'TERMINAL_ROWS=%q\n' "$rows"
    printf 'TERMINAL_COLS=%q\n' "$cols"
  fi
} > "$out_file"
