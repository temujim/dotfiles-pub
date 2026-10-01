#!/usr/bin/env bash
set -euo pipefail

# Post-restore helper (rewritten 2026-09-25, fixed 2026-10-01).
#
# Why the rewrite (2026-09-25): the old version slept 2s then sent `/history`
# + Enter as one tmux burst. Two independent failures made /history "stop
# working" after every reboot-restore:
#   1. Hermes boots for 10-30s under a 20-40 pane restore burst, so at +2s the
#      keystrokes raced the boot; and when they did land, hermes_cli's
#      rapid-input guard (_tui_handle_enter, <50ms since last text change)
#      classified the burst-Enter as a paste line break, so /history was never
#      submitted (it sat in the composer).
#   2. Some restored panes boot to a FRESH session (resume race at boot: no
#      "↻ Resumed session" banner, empty conversation_history). For those,
#      /history can only show the recent-sessions list.
#
# Why the 2026-10-01 fix: the rewrite SKIPPED every healthy pane
# (banner present -> `continue` before /history), so when a restore worked
# correctly — sessions back, banners shown — /history was NEVER sent. That is
# exactly the reported symptom: "restores previous sessions but /history is
# apparently not invoked". Now the banner only skips the /resume REPAIR step;
# /history is still sent to every pane holding a conversation (banner present
# OR --resume sid in argv). Only truly fresh panes (no banner, no sid) are
# left alone with their composer drafts.
#
# PACED = literal text first, pause, THEN Enter — an Enter arriving <50ms after
# text is treated as a paste newline by hermes and never submits.
#
# Logging: every run appends to $HERMES_RESTORE_LOG (default below), because
# the hook runs backgrounded from tmux with no terminal — the log is the only
# proof it fired. Dry run: HERMES_RESTORE_DRY_RUN=1 logs decisions without
# sending any keystrokes (safe against live sessions).
#
# Rollback: cp hermes_history_after_restore.sh.bak-20261001 over this file
# (2026-09-25 backup: hermes_history_after_restore.sh.bak-20260925).

BOOT_TIMEOUT="${HERMES_RESTORE_BOOT_TIMEOUT:-120}"
KEY_PACING="${HERMES_RESTORE_KEY_PACING:-0.7}"
READY_POLL="${HERMES_RESTORE_READY_POLL:-2}"
LOG_FILE="${HERMES_RESTORE_LOG:-$HOME/.local/share/tmux/resurrect/hermes_history_after_restore.log}"
DRY_RUN="${HERMES_RESTORE_DRY_RUN:-0}"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >>"$LOG_FILE" 2>/dev/null || true
}

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

# Extract the --resume <sid> value from the earliest real hermes process under
# the pane (earliest = lowest lstart among matching descendants). Mirrors
# save_command_strategies/hermes_agents.sh mapping rules.
pane_resume_sid() {
  local root="$1"
  ps -ax -o pid= -o ppid= -o lstart= -o command= | awk -v root="$root" '
    function month_num(m) {
      return index("JanFebMarAprMayJunJulAugSepOctNovDec", m) == 0 ? 0 : int((index("JanFebMarAprMayJunJulAugSepOctNovDec", m) + 2) / 3)
    }
    {
      pid=$1; ppid=$2
      lstart=$3" "$4" "$5" "$6" "$7
      $1=""; $2=""; $3=""; $4=""; $5=""; $6=""; $7=""
      sub(/^ +/, "")
      cmd[pid]=$0; parent[pid]=ppid; raw_lstart[pid]=lstart
    }
    END {
      for (pid in parent) {
        p=pid; depth=0
        while (p in parent && depth < 64) {
          if (parent[p] == root) {
            if (cmd[pid] ~ /(^|[\/[:space:]])hermes([[:space:]]|$)/) {
              if (match(cmd[pid], /--resume [0-9A-Za-z_-]+/)) {
                sid=substr(cmd[pid], RSTART+9, RLENGTH-9)
                split(raw_lstart[pid], L, " ")
                # macOS lstart: "Fri 25 Sep 09:00:00 2026" (day may be single digit)
                hhmm=L[4]; mmss_ok=(hhmm ~ /:/)
                rank=sprintf("%04d%02d%02d%s", L[6]+0, month_num(L[3]), L[2]+0, hhmm)
                if (best == "" || rank < best_rank) { best=sid; best_rank=rank }
              }
            }
            break
          }
          p=parent[p]; depth++
        }
      }
      print best
    }'
}

pane_ready() {
  # The hermes TUI is up when the pane shows its composer prompt marker.
  tmux capture-pane -p -t "$1" 2>/dev/null | grep -q "❯"
}

send_paced() {
  # $1 = pane, $2 = literal text. Text burst is safe; only Enter must be paced.
  if [ "$DRY_RUN" = "1" ]; then
    log "DRY-RUN would send to $1: $2"
    return 0
  fi
  tmux send-keys -t "$1" -l -- "$2" || return 0
  sleep "$KEY_PACING"
  tmux send-keys -t "$1" C-m || return 0
}

clear_composer() {
  # $1 = pane. C-u clears a stale composer line before our command.
  if [ "$DRY_RUN" = "1" ]; then
    return 0
  fi
  tmux send-keys -t "$1" C-u 2>/dev/null || true
  sleep "$KEY_PACING"
}

pane_already_resumed() {
  tmux capture-pane -p -t "$1" -S -2000 2>/dev/null |
    grep -q -e "↻ Resumed session" -e "Previous Conversation"
}

log "hook start dry_run=$DRY_RUN boot_timeout=$BOOT_TIMEOUT key_pacing=$KEY_PACING"
sleep "$READY_POLL"

scanned=0; hermes_panes=0; repaired=0; historied=0; skipped_fresh=0; skipped_notready=0

while IFS='|' read -r pane_id cmd; do
  case "$cmd" in
    hermes|Hermes|python|python*|Python*|zsh|bash|sh) ;;
    *) continue ;;
  esac
  scanned=$((scanned + 1))
  pane_pid=$(tmux display-message -p -t "$pane_id" '#{pane_pid}' 2>/dev/null || true)
  [ -n "$pane_pid" ] || continue
  pane_has_hermes_descendant "$pane_pid" || continue
  hermes_panes=$((hermes_panes + 1))

  # 1) Wait for the hermes TUI prompt (boot can take 30s+ in a big restore burst).
  waited=0
  until pane_ready "$pane_id"; do
    sleep "$READY_POLL"
    waited=$((waited + READY_POLL))
    [ "$waited" -ge "$BOOT_TIMEOUT" ] && break
  done
  if ! pane_ready "$pane_id"; then
    log "skip $pane_id: TUI prompt never appeared within ${BOOT_TIMEOUT}s"
    skipped_notready=$((skipped_notready + 1))
    continue
  fi

  sid=$(pane_resume_sid "$pane_pid")
  resumed=0
  if pane_already_resumed "$pane_id"; then
    resumed=1
  fi

  # 2) Repair only panes that need it: no banner but a known sid in argv.
  # Fresh/active chats (no sid in argv) and their composer drafts are left alone.
  if [ "$resumed" = "0" ] && [ -n "$sid" ]; then
    log "repair $pane_id: no resume banner, sending /resume $sid"
    clear_composer "$pane_id"
    send_paced "$pane_id" "/resume $sid"
    repaired=$((repaired + 1))
    if [ "$DRY_RUN" = "1" ]; then
      sleep 0
    else
      sleep 6
    fi
  fi

  # 3) Show the conversation. Healthy panes (banner present) reach here too —
  # the banner only skipped the repair above, never this history step.
  if [ "$resumed" = "1" ] || [ -n "$sid" ]; then
    log "history $pane_id: sending /history (resumed=$resumed sid=${sid:-none})"
    clear_composer "$pane_id"
    send_paced "$pane_id" "/history"
    historied=$((historied + 1))
  else
    log "skip $pane_id: fresh pane (no banner, no --resume sid); leaving composer alone"
    skipped_fresh=$((skipped_fresh + 1))
  fi
done < <(tmux list-panes -a -F '#{pane_id}|#{pane_current_command}' 2>/dev/null)

log "hook done scanned=$scanned hermes_panes=$hermes_panes repaired=$repaired historied=$historied skipped_fresh=$skipped_fresh skipped_notready=$skipped_notready"

exit 0
