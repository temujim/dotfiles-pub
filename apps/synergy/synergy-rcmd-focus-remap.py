#!/usr/bin/env python3
"""Watch Synergy server logs and map Keychron Right CMD -> Left Control only while example-client holds focus.

v4 changes (2026-09-15):
- Staleness-checked bootstrap + server-restart awareness. BUG FIXED: on login or a
  macOS fast-user switch (esp. profile-b -> user), the watcher read the NEWEST
  Synergy log, whose last "switch ... to example-client" line could be HOURS or DAYS old
  (from a previous session). It then armed the Right-CMD->Ctrl map even though the
  user had just landed on the Mac — Right CMD silently acted as Ctrl. v4 parses log
  timestamps and (a) ignores switch lines older than STALE_SWITCH_LIMIT seconds,
  (b) treats a newer "started server" line as focus returning to the Mac (Synergy
  always gives the server screen control on startup), and (c) defaults to UNKNOWN ->
  mapping CLEARED (Right CMD native on the Mac) whenever focus cannot be proven
  fresh. Safe-by-default: worst case is Right CMD behaving as Command on linuxclient until
  the next real screen switch, never as Ctrl on the Mac.

v3 changes (2026-09-07):
- Periodic reconcile loop: every 5s the watcher re-asserts its intent through the
  same read-modify-write path (a no-op when the array already matches). This makes
  it self-healing against external full-array hidutil clears — e.g. the
  macos-keymap.sh autostart/apply/rollback gate, which legitimately wipes the whole
  UserKeyMapping when enforcing the external-keyboard login policy. Ownership is
  now explicit: the watcher owns ONLY the Keychron-scoped entry; macos-keymap.sh
  owns every other mapping.

v2 changes (2026-08-26):
- Multi-log: tails BOTH `~/Library/Logs/Synergy/synergy.log` (GUI-managed server, e.g. the
  profile-b profile) and `~/Library/Logs/Synergy/synergy-server.log` (CLI-launched server with
  --config synergy-server.conf, e.g. the user profile). The GUI app logs to `synergy.log`;
  a CLI server launched with a config named synergy-server.conf logs to `synergy-server.log`.
  Only the file(s) that exist are watched; the newest switch line wins.
- Read-modify-write hidutil: instead of clearing/overwriting the whole UserKeyMapping array,
  the watcher now ONLY adds the Keychron-scoped entry (VendorID 13364 / ProductID 53297,
  Right CMD 0x7000000E7 -> Left Control 0x7000000E0) while example-client has focus, and ONLY
  removes that same entry when focus returns to the Mac. All other per-keyboard mappings
  (e.g. Apple built-in Right CMD -> Backspace, F13 remaps) are preserved untouched.

Behavior (unchanged from v1):
- While the cursor is on `linuxclient`: the Keychron dongle's physical Right CMD
  key is remapped to Left Control (clean Control_L on the client; Right Control 0xE4 causes
  Synergy's Mac server to double-emit an orphaned Control_R that latches Ctrl stuck).
- While the cursor is on the Mac: no Keychron mapping -> Right CMD is native Command.
- Left CMD is never touched. Client-side xmodmap cannot work because the Synergy server
  collapses Left/Right Command into one modifier before transmission.
"""
from __future__ import annotations

import json
import re
import subprocess
import time
from datetime import datetime
from pathlib import Path

LOG_CANDIDATES = (
    Path.home() / "Library/Logs/Synergy/synergy.log",
    Path.home() / "Library/Logs/Synergy/synergy-server.log",
)
STATE_DIR = Path.home() / ".local/state"
STATE_DIR.mkdir(parents=True, exist_ok=True)
STATE_FILE = STATE_DIR / "synergy-rcmd-focus.state"

KEYCHRON_E7 = 0x7000000E7  # Right Command / Right GUI
LEFT_CTRL = 0x7000000E0    # Left Control (clean client Control_L; 0xE4 latches stuck)
KEYCHRON_VID = 13364
KEYCHRON_PID = 53297
KEYCHRON_ENTRY = {
    "HIDKeyboardModifierMappingSrc": KEYCHRON_E7,
    "HIDKeyboardModifierMappingDst": LEFT_CTRL,
    "VendorID": KEYCHRON_VID,
    "ProductID": KEYCHRON_PID,
}

LINUXCLIENT = "linuxclient"
mac = "mac-main"  # canonical server screen name (informational; dest-based logic)

RECONCILE_INTERVAL = 5.0  # seconds between intent re-asserts (v3 self-healing)

# v4: a switch line older than this is treated as stale history from a previous
# session (login / profile switch), not as current focus.
STALE_SWITCH_LIMIT = 600  # seconds

# Lines that prove the server (re)started and therefore that control is back on
# the Mac screen until linuxclient actively switches.
_SERVER_START_RE = re.compile(r"\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\].*started server")
_SWITCH_RE = re.compile(
    r"\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\].*switch from \"([^\"]+)\" to \"([^\"]+)\""
)
_LOG_TS_FMT = "%Y-%m-%dT%H:%M:%S"


def _parse_log_ts(stamp: str):
    try:
        return datetime.strptime(stamp, _LOG_TS_FMT)
    except ValueError:
        return None


def last_focus_event_from(text: str):
    """Return the newest focus event in `text` as (dest_screen, when) or None.

    v4.1: events are selected by FILE ORDER (later line wins), not timestamp
    comparison — same-second switch sequences are real here (the shared-edge
    bounce produces mac->linuxclient + linuxclient->mac within one second, and timestamp
    tie-breaking kept the FIRST switch, wedging the watcher in 'linuxclient focused').
    Timestamps are used only for staleness decisions in read_tails().
    A switch line counts only if no later "started server" line follows in file
    order — a (re)started server hands control to the Mac screen.
    """
    start_seq = -1
    switch_seq = -1
    newest_start = None
    newest_switch = None  # (dest, when)
    seq = 0
    for line in text.splitlines():
        seq += 1
        m = _SERVER_START_RE.search(line)
        if m:
            when = _parse_log_ts(m.group(1))
            if when:
                newest_start = when
                start_seq = seq
            continue
        m = _SWITCH_RE.search(line)
        if m:
            when = _parse_log_ts(m.group(1))
            if when:
                newest_switch = (m.group(3), when)
                switch_seq = seq
    if newest_switch and switch_seq > start_seq:
        return newest_switch
    return None


def _hidutil_get() -> list[dict]:
    """Return the current UserKeyMapping array as dicts, parsed from hidutil plist output."""
    try:
        out = subprocess.check_output(
            ["/usr/bin/hidutil", "property", "--get", "UserKeyMapping"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []
    entries = []
    for block in re.findall(r"\{([^}]*)\}", out):
        kv = {}
        for key, val in re.findall(
            r"(HIDKeyboardModifierMapping(?:Src|Dst)|ProductID|VendorID)\s*=\s*(\d+)",
            block,
        ):
            kv[key] = int(val)
        if kv:
            entries.append(kv)
    return entries


def _as_hidutil_json(entries: list[dict]) -> str:
    return json.dumps({"UserKeyMapping": entries})


def set_mapping(linuxclient_focused: bool) -> None:
    """Read current array, add/remove only the Keychron entry, write back."""
    current = _hidutil_get()
    keychron_in_array = any(
        e.get("VendorID") == KEYCHRON_VID
        and e.get("ProductID") == KEYCHRON_PID
        and e.get("HIDKeyboardModifierMappingSrc") == KEYCHRON_E7
        for e in current
    )
    if linuxclient_focused and not keychron_in_array:
        current.append(dict(KEYCHRON_ENTRY))
    elif not linuxclient_focused and keychron_in_array:
        current = [
            e
            for e in current
            if not (
                e.get("VendorID") == KEYCHRON_VID
                and e.get("ProductID") == KEYCHRON_PID
                and e.get("HIDKeyboardModifierMappingSrc") == KEYCHRON_E7
            )
        ]
    else:
        return  # no change needed
    subprocess.run(
        ["/usr/bin/hidutil", "property", "--set", _as_hidutil_json(current)],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def write_state(name: str) -> None:
    STATE_FILE.write_text(name + "\n")


def last_dest_from(text: str) -> str | None:
    last = None
    for line in text.splitlines():
        if 'switch from "' not in line or ' to "' not in line:
            continue
        try:
            dest = line.split(' to "', 1)[1].split('"', 1)[0]
        except IndexError:
            continue
        last = dest
    return last


def read_tails() -> tuple[dict[Path, int], str | None]:
    """v4: Return file positions and the CURRENT focus screen, or None if unknown.

    A focus is only returned if the newest switch event is fresher than any
    "started server" line AND younger than STALE_SWITCH_LIMIT seconds. Anything
    else (old logs, stale history, profile switch) yields None -> mapping cleared
    (Right CMD native on the Mac). This is the safe default after login.
    """
    positions: dict[Path, int] = {}
    newest = None
    newest_mtime = 0.0
    for path in LOG_CANDIDATES:
        if not path.exists():
            continue
        st = path.stat()
        positions[path] = st.st_size
        if st.st_mtime >= newest_mtime:
            newest_mtime = st.st_mtime
            newest = path
    focus = None
    if newest is not None:
        try:
            out = subprocess.check_output(
                ["/usr/bin/tail", "-n", "120", str(newest)], text=True
            )
            event = last_focus_event_from(out)
            if event is not None:
                dest, when = event
                age = datetime.now() - when
                if age.total_seconds() <= STALE_SWITCH_LIMIT:
                    focus = dest
                # else: stale history from a previous session -> stay unknown
        except subprocess.CalledProcessError:
            pass
    return positions, focus


def follow() -> None:
    positions, dest = read_tails()
    # v4: dest may be None (unknown/stale) -> treat as Mac focus (mapping cleared).
    mapped = dest == LINUXCLIENT
    set_mapping(mapped)
    write_state(dest or "unknown")

    # v3: periodic reconcile. Any external full-array hidutil clear (macos-keymap
    # autostart/rollback/apply, stock-reset scripts) can wipe the Keychron entry
    # while this watcher's in-memory `mapped` flag stays unchanged — the event
    # path would then never re-add it until the next screen switch. Every
    # RECONCILE_INTERVAL seconds, re-assert intent through the same
    # read-modify-write path (a no-op when the array already matches).
    last_reconcile = time.monotonic()
    while True:
        time.sleep(0.15)
        now = time.monotonic()
        if now - last_reconcile >= RECONCILE_INTERVAL:
            last_reconcile = now
            set_mapping(dest == LINUXCLIENT)
        for path in LOG_CANDIDATES:
            if not path.exists():
                continue
            size = path.stat().st_size
            pos = positions.get(path, 0)
            if size < pos:  # log rotated/truncated
                pos = 0
            if size == pos:
                continue
            with path.open("r", errors="replace") as fh:
                fh.seek(pos)
                chunk = fh.read()
                positions[path] = fh.tell()
            # v4: react to both switch lines AND server restarts. A fresh chunk
            # containing a "started server" line (and no later switch) means
            # control returned to the Mac -> clear the mapping.
            if _SWITCH_RE.search(chunk) or _SERVER_START_RE.search(chunk):
                new_event = last_focus_event_from(chunk)
                new_dest = new_event[0] if new_event else None
                if new_dest != dest:
                    dest = new_dest
                    want = dest == LINUXCLIENT
                    if want != mapped:
                        set_mapping(want)
                        mapped = want
                    write_state(dest or "unknown")


if __name__ == "__main__":
    follow()