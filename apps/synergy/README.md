# Synergy KVM settings (macOS server ↔ example-client Linux client)

Captured from the live user Mac 2026-08-25, updated 2026-08-26 for watcher v2
(multi-log, hidutil-preserving) and multi-macOS-profile seamless install. Live files on
each Mac profile are canonical — if a machine config drifts, re-run the installer.

## Files

| Repo file | Source on Mac | Transform |
|-----------|--------------|-----------|
| `synergy-server.conf` | `~/Library/Preferences/Synergy/synergy-server.conf` | none (verbatim) |
| `synergy-rcmd-focus-remap.py` | `~/.local/bin/synergy-rcmd-focus-remap.py` | none (portable via `$HOME`) |
| `com.user.synergy-rcmd-focus-remap.plist.template` | `~/Library/LaunchAgents/com.user.synergy-rcmd-focus-remap.plist` | `@HOME@` → `$HOME` (install-time sed) |
| `install-synergy-profile.sh` | — | per-logged-in-user installer (no sudo) |

NOT committed (by design): `synergyCert.pem` (certificate, `*.pem` gitignored), `db.json` /
`local.json` / `UISetting.json` (GUI state), `synergy.conf` (every profile's GUI-generated
layout), all `*.bak-*` files.

## Topology (canonical config)

- Server: `mac-main` (this Mac) with `linuxclient` (Debian/X11 Linux client)
  to its RIGHT (`right(0,100)` / `left(0,100)`).
- example-client modifier mapping: `alt = super`, `super = alt` → Mac Left Command arrives on
  Linux as `Alt_L` (keycode 64), Left Option as `Super_L` (133). macOS keeps native keys
  locally.
- Switch hotkeys: `keystroke(Control+Alt+q) = switchInDirection(left)` and
  `keystroke(Control+Alt+w) = switchInDirection(right)`.
  (These evaluate input from whichever screen holds control: W fires only from the Mac, Q only
  from linuxclient in this 2-screen topology.)
- Clipboard sharing (4000 KB), heartbeat 5000 ms, relative mouse moves.

## What the watcher does (Right CMD → CTRL on example-client, native on Mac)

`synergy-rcmd-focus-remap.py` (v2) tails the Synergy server log and, while the cursor is on
`linuxclient`, applies a **Keychron-scoped** hidutil remap (Right CMD `0x7000000E7` →
**Left Control** `0x7000000E0` on Keychron Link VID 13364 / PID 53297 only); on the Mac it
removes just that entry. Left CMD is never touched.

v2 changes:
- **Multi-log** — tails BOTH `~/Library/Logs/Synergy/synergy.log` (GUI-managed server, e.g.
  a profile) and `~/Library/Logs/Synergy/synergy-server.log` (CLI-launched server,
  e.g. the user profile). A GUI server logs to `synergy.log`; a CLI server launched with
  `--config .../synergy-server.conf` logs to `synergy-server.log`. v1 tailed only
  `synergy-server.log` and was deaf under GUI-managed profiles.
- **Read-modify-write hidutil** — v2 adds/removes ONLY the Keychron (13364/53297) entry,
  preserving all other per-keyboard mappings (e.g. Apple built-in Right CMD → Backspace, F13
  remaps). v1 replaced the whole `UserKeyMapping` array on every focus change, wiping other maps.

Why Left Control (`0xE0`) and NOT Right Control (`0xE4`): Synergy's Mac server double-emits a
Right-Control press (orphaned `Control_R` keycode 105 with no matching release), which latches
Ctrl stuck on the Linux client. Left Control maps to a single clean `Control_L` (keycode 37).
Verified 2026-08-25 with physical-press probes on linuxclient.

Why not client-side xmodmap: the Synergy server collapses Left/Right Command into one modifier
before transmission (both arrive as `Alt_L` under `super = alt`), so the client never sees a
distinct right-command event.

## Seamless across macOS profiles (profile-a, profile-b, profile-c)

Synergy runs per logged-in user on this Mac — each login runs its own server. Switching
accounts must still present the same KVM behavior. Two things make that possible:

1. **Same watcher + config in every profile.** Run the installer from each user you use.
2. **Same server TLS cert everywhere (`synergyCert.pem`).** The example-client client **pins the
   server cert by SHA-256 fingerprint** (its `db.json` → `data.security.fingerprint`). If one
   profile runs the server with a *different* cert than the one linuxclient has pinned, the TLS
   handshake fails / reconnect-flaps. So all profiles must serve the **same** cert — the one
   linuxclient currently trusts.

   The canonical cert is the one linuxclient pins today (fingerprint `REDACTED_FINGERPRINT`).
   It is staged alongside the installer (not in git). Any profile that installs with the
   installer beside a `synergyCert.pem` gets the canonical cert installed (with a backup if a
   different cert was present).

### Deploy per profile (each account that uses the Mac)

From a **staged shared dir** (files readable by all three accounts):
```bash
bash /Users/Shared/Synergy-Profile/install-synergy-profile.sh
```
From a **dotfiles-mac clone** (cert must be copied beside it first):
```bash
bash ~/dotfiles-mac/apps/synergy/install-synergy-profile.sh
```

Run it once per account: **user**, **profile-b**, and **profile-c** (profile-c rarely used, but a
single command future-proofs it). The installer does not need sudo — it writes only into that
user's `$HOME`. It is idempotent and safe to re-run.

If a profile has never opened the Synergy app, its `com.symless.synergy3.plist` (GUI
auto-start) is missing — the installer warns; `open -a Synergy` once to register it, or launch
the server CLI manually (command is printed).

### What the live server actually uses
The modifier swap lives in BOTH the canonical 2-screen config AND the GUI-generated
`synergy.conf` (the client's `db.json` carries `Alt→Super`/`Super→Alt` for example-client), so the
keymapping holds regardless of whether a profile runs the GUI server or a CLI `--config`
server. The watcher works with either log path.

## Revert (remove the Right-CMD behavior)

```bash
launchctl bootout gui/$(id -u)/com.user.synergy-rcmd-focus-remap
rm -f ~/Library/LaunchAgents/com.user.synergy-rcmd-focus-remap.plist
rm -f ~/.local/bin/synergy-rcmd-focus-remap.py
rm -f ~/.local/state/synergy-rcmd-focus.state \
      ~/.local/state/synergy-rcmd-focus.log ~/.local/state/synergy-rcmd-focus.err
hidutil property --set '{"UserKeyMapping":[]}'
```
(That last `hidutil` clear is the aggressive full reset — on a v2 install it is not needed;
removing just the Keychron entry is enough.)

## Verify / diagnose stuck CTRL on the client

```bash
# listener on linuxclient (before pressing keys on the Mac)
ssh user@host.example 'DISPLAY=:0 nohup timeout 15 xinput test-xi2 --root 3 > /tmp/probe.log 2>&1 &'
# press Right CMD on the Keychron; expect clean "Press 37 / Release 37" pairs.
# An orphaned "Press 105" with no matching release = the 0xE4 double-emit bug.
```

## Restart procedure & connection health

```bash
pkill -f 'synergy-core server'   # synergy-service auto-respawns it (~5 s)
sleep 8
tail ~/Library/Logs/Synergy/synergy.log          # GUI server log (or synergy-server.log for CLI)
lsof -nP -iTCP:24800                              # want one ESTABLISHED 192.0.2.10 -> 192.0.2.x* pair
```
If the server log repeats `accepted secure socket` → `new client disconnected` with **no**
`client "<name>" has connected` line, the peer is reconnect-flapping (often a TLS cert
fingerprint mismatch or a stale server) — clean kill + respawn clears it.

See the `synergy-kvm-workflows` Hermes skill and the PrivateVault second-brain note
`04 Resources/Terminal/Synergy macOS-Linux KVM Setup` for the full writeup.