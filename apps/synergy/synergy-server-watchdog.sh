#!/bin/bash
# Synergy server watchdog (user profile, Mac "example-host")
# Heals two known failure modes:
#  1. Server process dead -> kill triggers launchd/synergy-service auto-respawn
#  2. Ghost client registration (endless "new client disconnected" flap,
#     client sees "server already has a connected client with our name")
#     -> restart server core so its registration table clears
# Logs: ~/Library/Logs/Synergy/synergy-watchdog.log

LOG=~/Library/Logs/Synergy/synergy-server.log
WLOG=~/Library/Logs/Synergy/synergy-watchdog.log
STAMP() { date "+%Y-%m-%dT%H:%M:%S"; }

srv_pids=$(pgrep -f 'synergy-core server')

# 1. No server process at all -> nudge respawn
if [ -z "$srv_pids" ]; then
  echo "$(STAMP) no server process found; pinging synergy-service" >> "$WLOG"
  pkill -f 'synergy-service' 2>/dev/null
  exit 0
fi

# 2. Ghost-client flap detection: many disconnects, no successful connect recently
# GHOST-FLAP vs LINUXCLIENT-DOWN (2026-09-07 lesson): a third-party machine (example-host,
# 192.0.2.20) repeatedly probes :24800 and is rejected by the 2-screen config,
# producing an endless "new client disconnected" flap with zero "has connected".
# Restarting the core on that pattern kills linuxclient's HEALTHY session every ~3 min
# (Right CMD presses die mid-use). The restart is only warranted when the flap
# has actually locked linuxclient out (its registration is stale: linuxclient's client can't
# re-register). So: require BOTH (a) the flap AND (b) no established TCP conn
# from example-client 192.0.2.10 to :24800 right now.
tail -120 "$LOG" 2>/dev/null > /tmp/syn-wd-tail.txt
disc=$(grep -c "new client disconnected" /tmp/syn-wd-tail.txt)
conn=$(grep -c "has connected" /tmp/syn-wd-tail.txt)
linuxclient_est=$(netstat -an -ptcp 2>/dev/null | grep 'ESTABLISHED' | grep '192.0.2.10' | grep -c '24800')
if [ "$disc" -ge 8 ] && [ "$conn" -eq 0 ] && [ "$linuxclient_est" -eq 0 ]; then
  # only act if this flap persisted across two consecutive checks
  FLAG=/tmp/syn-wd-flap.flag
  if [ -f "$FLAG" ]; then
    echo "$(STAMP) ghost-client flap confirmed (disc=$disc conn=$conn); restarting server core" >> "$WLOG"
    rm -f "$FLAG"
    pkill -f 'synergy-core server'
  else
    touch "$FLAG"
    echo "$(STAMP) ghost-client flap suspected (disc=$disc conn=$conn); will confirm next cycle" >> "$WLOG"
  fi
else
  rm -f /tmp/syn-wd-flap.flag
fi

# keep watchdog log from growing unbounded
if [ -f "$WLOG" ]; then
  tail -200 "$WLOG" > "$WLOG.tmp" 2>/dev/null && mv "$WLOG.tmp" "$WLOG"
fi
exit 0
