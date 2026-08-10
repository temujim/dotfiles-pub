#!/usr/bin/env bash
set -euo pipefail

# Post-restore helper. Give Hermes panes a moment to launch, then send /history
# into panes running Hermes so the restored conversation list is visible.

sleep 2

pane_has_hermes_descendant() {
  local root="$1"
  ps -ax -o pid= -o ppid= -o command= | awk -v root="$root" '
    {
      pid=$1; ppid=$2; $1=""; $2=""; sub(/^  */, ""); cmd[pid]=$0; parent[pid]=ppid
    }
    END {
      for (pid in parent) {
        p=pid
        while (p in parent) {
          if (parent[p] == root) {
            if (cmd[pid] ~ /(^|[\/[:space:]])hermes([[:space:]]|$)/) { found=1 }
            break
          }
          p=parent[p]
        }
      }
      exit(found ? 0 : 1)
    }'
}

tmux list-panes -a -F '#{pane_id}	#{pane_current_command}' 2>/dev/null |
while IFS=$'\t' read -r pane_id cmd; do
  case "$cmd" in
    hermes|Hermes|python|python3|zsh|bash)
      pane_pid=$(tmux display-message -p -t "$pane_id" '#{pane_pid}' 2>/dev/null || true)
      if [ -n "$pane_pid" ] && pane_has_hermes_descendant "$pane_pid"; then
        tmux send-keys -t "$pane_id" '/history' C-m || true
      fi
      ;;
  esac
done
