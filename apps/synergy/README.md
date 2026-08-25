# Synergy KVM settings (macOS server ↔ example-client Linux client)

Captured from the live user Mac 2026-08-25. Live files are canonical — if the
machine config drifts from these copies, re-copy from the source paths below.

## Files

| Repo file | Source on Mac | Transform |
|-----------|--------------|-----------|
| `synergy-server.conf` | `~/Library/Preferences/Synergy/synergy-server.conf` | none (verbatim) |
| `synergy-rcmd-focus-remap.py` | `~/.local/bin/synergy-rcmd-focus-remap.py` | none (portable via `$HOME`) |
| `com.user.synergy-rcmd-focus-remap.plist.template` | `~/Library/LaunchAgents/com.user.synergy-rcmd-focus-remap.plist` | `~` → `@HOME@` (install-time sed) |

NOT committed (by design): `synergyCert.pem` (certificate), `db.json` /
`local.json` / `UISetting.json` (GUI state), `synergy.conf` (stale GUI 5-screen
layout), all `*.bak-*` files.

## What `synergy-server.conf` configures

- Screen topology: `mac-main` (server) with `linuxclient`
  (Linux client) to its RIGHT (`right(0,100)` / `left(0,100)`).
- example-client modifier mapping: `alt = super`, `super = alt` → mac Left Command
  arrives on Linux as `Alt_L` (keycode 64), Left Option as `Super_L` (133).
  macOS keeps native keys locally.
- Switch hotkeys: `keystroke(Control+Alt+q) = switchInDirection(left)` and
  `keystroke(Control+Alt+w) = switchInDirection(right)`. These evaluate input
  from whichever screen holds control (W fires only from the Mac, Q only from
  linuxclient in this 2-screen topology).
- Clipboard sharing (4000 KB), heartbeat 5000 ms, relative mouse moves.

## What the watcher does (Right CMD → CTRL on example-client, native on Mac)

`synergy-rcmd-focus-remap.py` (run by the LaunchAgent) tails the Synergy server
log for `switch from "X" to "Y"` and:

- While the cursor/focus is on `linuxclient`: applies a Keychron-scoped
  hidutil remap — Right CMD (`0x7000000E7`) → **Left Control**
  (`0x7000000E0`) on Keychron Link VID 13364 / PID 53297 only.
- While focus is on the Mac: clears `UserKeyMapping` so Right CMD is native
  Command again.
- Left CMD is never touched.

Why Left Control (`0xE0`) and NOT Right Control (`0xE4`): Synergy's macOS server
double-emits a Right-Control press (orphaned `Control_R` keycode 105 with no
matching release), which latches Ctrl stuck on the Linux client. Left Control
maps to a single clean `Control_L` (keycode 37) press/release pair. Verified
2026-08-25 with physical-press probes on linuxclient.

Why not client-side xmodmap: the Synergy server collapses Left/Right Command into
one modifier before transmission (both arrive as `Alt_L` under `super = alt`),
so the client never sees a distinct right-command event.

## Install on a target Mac

```bash
# 1. Copy the watcher script into place
mkdir -p ~/.local/bin
cp synergy-rcmd-focus-remap.py ~/.local/bin/

# 2. Install the LaunchAgent (template → real, @HOME@ → $HOME)
mkdir -p ~/Library/LaunchAgents
sed "s|@HOME@|$HOME|g" \
  com.user.synergy-rcmd-focus-remap.plist.template \
  > ~/Library/LaunchAgents/com.user.synergy-rcmd-focus-remap.plist

# 3. Load it
launchctl bootout gui/$(id -u)/com.user.synergy-rcmd-focus-remap 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.synergy-rcmd-focus-remap.plist

# 4. Point Synergy at the server config (via its GUI/CLI), then confirm:
#    hidutil property --get UserKeyMapping  # empty on Mac, E7→E0 entry while linuxclient focused
```

## Revert (remove the Right-CMD behavior)

```bash
launchctl bootout gui/$(id -u)/com.user.synergy-rcmd-focus-remap
rm -f ~/Library/LaunchAgents/com.user.synergy-rcmd-focus-remap.plist
rm -f ~/.local/bin/synergy-rcmd-focus-remap.py
rm -f ~/.local/state/synergy-rcmd-focus.state \
      ~/.local/state/synergy-rcmd-focus.log ~/.local/state/synergy-rcmd-focus.err
hidutil property --set '{"UserKeyMapping":[]}'
```

## Verify / diagnose stuck CTRL on the client

```bash
# listener on linuxclient (before pressing keys on the Mac)
ssh user@host.example 'DISPLAY=:0 nohup timeout 15 xinput test-xi2 --root 3 > /tmp/probe.log 2>&1 &'
# press Right CMD on the Keychron; expect clean "Press 37 / Release 37" pairs.
# An orphaned "Press 105" with no matching release = the old 0xE4 double-emit bug.
```

See the `synergy-kvm-workflows` Hermes skill and the PrivateVault second-brain note
`04 Resources/Terminal/Synergy macOS-Linux KVM Setup` for the full writeup.
