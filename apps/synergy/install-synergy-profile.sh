#!/usr/bin/env bash
# install-synergy-profile.sh — install the canonical Synergy KVM profile for the
# CURRENT logged-in macOS user. No sudo required (writes only into $HOME).
#
# Works identically from any of the three Mac profiles (user, profile-b, profile-c):
#   bash /Users/Shared/Synergy-Profile/install-synergy-profile.sh
#   # or from a dotfiles-mac clone:
#   bash ~/dotfiles-mac/apps/synergy/install-synergy-profile.sh
#
# What it does (idempotent):
#   1. Installs the canonical 2-screen server config ( mac-main<-> linuxclient,
#      alt<->super swap + Ctrl+Alt+Q/W switch hotkeys) at ~/Library/Preferences/Synergy/synergy-server.conf
#   2. Installs the Right-CMD -> Left-Control focus watcher (v2, multi-log, preserves
#      other hidutil mappings) at ~/.local/bin/synergy-rcmd-focus-remap.py
#   3. Installs + (re)loads its LaunchAgent (com.user.synergy-rcmd-focus-remap)
#   4. Installs the CANONICAL server TLS cert (the one example-client pins by fingerprint)
#      at ~/Library/Preferences/Synergy/synergyCert.pem — backups any existing cert first.
#   5. Prints a verification summary (agent loaded, watcher state, mapping, cert match).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"

SYNERGY_PREFS="${HOME_DIR}/Library/Preferences/Synergy"
LAUNCH_AGENTS="${HOME_DIR}/Library/LaunchAgents"
LOCAL_BIN="${HOME_DIR}/.local/bin"
STATE_DIR="${HOME_DIR}/.local/state"
WATCHER_NAME="synergy-rcmd-focus-remap"
LAUNCH_LABEL="com.user.synergy-rcmd-focus-remap"

CONF_SRC="${SRC}/synergy-server.conf"
WATCHER_SRC="${SRC}/synergy-rcmd-focus-remap.py"
PLIST_TEMPLATE="${SRC}/com.user.synergy-rcmd-focus-remap.plist.template"
CERT_SRC="${SRC}/synergyCert.pem"

echo "== Synergy profile installer =="
echo "   user:        ${HOME_DIR}"
echo "   source dir:  ${SRC}"
echo

# ---- sanity ----
missing=0
for f in "$CONF_SRC" "$WATCHER_SRC" "$PLIST_TEMPLATE"; do
    [ -f "$f" ] || { echo "MISSING $f" >&2; missing=1; }
done
[ -f "$CERT_SRC" ] || echo "NOTE: no synergyCert.pem beside the installer — skipping the TLS-cert step."
if [ "$missing" -eq 1 ]; then
    echo "ABORT: required files are missing from the source dir." >&2
    exit 1
fi

mkdir -p "$SYNERGY_PREFS" "$LAUNCH_AGENTS" "$LOCAL_BIN" "$STATE_DIR"
umask 022

# ---- 1. canonical server config ----
conf_target="$SYNERGY_PREFS/synergy-server.conf"
if [ -f "$conf_target" ] && ! cmp -s "$conf_target" "$CONF_SRC"; then
    cp "$conf_target" "$conf_target.bak-$(date +%Y%m%d-%H%M%S)"
    echo "   backed up existing $conf_target"
fi
cp "$CONF_SRC" "$conf_target"
echo "   installed: $conf_target"
grep -q 'alt = super' "$conf_target" && grep -q 'super = alt' "$conf_target" \
    && echo "     example-client alt<->super swap: present"

# ---- 2. watcher script ----
cp "$WATCHER_SRC" "$LOCAL_BIN/$WATCHER_NAME.py"
chmod +x "$LOCAL_BIN/$WATCHER_NAME.py"
echo "   installed: $LOCAL_BIN/$WATCHER_NAME.py"

# ---- 3. LaunchAgent ----
plist_target="$LAUNCH_AGENTS/$LAUNCH_LABEL.plist"
sed "s|@HOME@|$HOME_DIR|g" "$PLIST_TEMPLATE" > "$plist_target"
launchctl bootout "gui/$(id -u)/$LAUNCH_LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$plist_target"
echo "   loaded LaunchAgent: $LAUNCH_LABEL"

# ---- 4. canonical TLS cert ----
if [ -f "$CERT_SRC" ]; then
    cert_target="$SYNERGY_PREFS/synergyCert.pem"
    if [ -f "$cert_target" ] && ! cmp -s "$cert_target" "$CERT_SRC"; then
        cp "$cert_target" "$cert_target.bak-$(date +%Y%m%d-%H%M%S)"
        echo "   WARNING: existing cert differed from the canonical one — backed up to .bak-*"
        echo "     (example-client pins the canonical cert's fingerprint; a different cert means TLS handshake failures)"
    fi
    cp "$CERT_SRC" "$cert_target"
    echo "   installed canonical cert: $cert_target"
fi

# ---- 5. GUI auto-start sanity ----
if [ ! -f "$LAUNCH_AGENTS/com.symless.synergy3.plist" ]; then
    echo "   NOTE: Synergy GUI auto-start agent (com.symless.synergy3.plist) not present."
    echo "         Open the Synergy app once (open -a Synergy) so it registers auto-start for this profile,"
    echo "         or start the server manually with:"
    echo "         /Applications/Synergy.app/Contents/MacOS/synergy-core server -f --no-tray --ipc -c $conf_target --name  mac-main--enable-crypto --tls-cert $SYNERGY_PREFS/synergyCert.pem --debug INFO --address 0.0.0.0:24800"
fi

# ---- verification ----
echo
echo "== Verification =="
sleep 1
if launchctl list | grep -q "$LAUNCH_LABEL"; then
    echo "  [OK] LaunchAgent loaded (launchctl list | grep $LAUNCH_LABEL)"
else
    echo "  [FAIL] LaunchAgent not in launchctl"
fi
if pgrep -f "$WATCHER_NAME.py" >/dev/null; then
    echo "  [OK] watcher process running"
else
    echo "  [FAIL] watcher process not running"
fi
state_file="$STATE_DIR/synergy-rcmd-focus.state"
if [ -f "$state_file" ]; then
    echo "  [OK] watcher state: $(cat "$state_file")"
else
    echo "  [WARN] state file not written yet (watcher waits for a switch event or log line)"
fi
hidutil property --get UserKeyMapping
echo "  (above: live UserKeyMapping — Keychron 13364/53297 E7->E0 entry appears only while example-client holds the cursor)"
if [ -f "$CERT_SRC" ]; then
    echo "  canonical cert fingerprint: $(openssl x509 -in "$CERT_SRC" -noout -fingerprint -sha256 2>/dev/null | sed 's/.*=//')"
    if [ -f "$cert_target" ]; then
        echo "  installed cert fingerprint:  $(openssl x509 -in "$cert_target" -noout -fingerprint -sha256 2>/dev/null | sed 's/.*=//')"
    fi
fi
for log in "$HOME_DIR/Library/Logs/Synergy/synergy.log" "$HOME_DIR/Library/Logs/Synergy/synergy-server.log"; do
    [ -f "$log" ] && echo "  watcher tail target exists: $log"
done
echo
echo "Done for profile ${HOME_DIR}. Repeat this command from each profile you use on this Mac."