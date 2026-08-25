#!/usr/bin/env python3
"""Watch Synergy server log and apply Keychron RCMD->RCTRL only while example-client has focus.

When the Mac holds the cursor, UserKeyMapping is empty so Right CMD stays native.
when example-client holds control, Keychron VID/PID 13364/53297 remaps Right CMD
to LEFT Control (0x7000000E0). Left Control is used (not Right Control 0xE4)
because Synergy's mac server double-emits a Right-Control press (orphaned, never
released) that leaves Control latched/stuck on the client; Left Control maps
cleanly to a single Control_L and does not stick. Left CMD is never touched.
"""
from __future__ import annotations

import os
import subprocess
import time
from pathlib import Path

LOG = Path.home() / "Library/Logs/Synergy/synergy-server.conf"
# actual log path
LOG = Path.home() / "Library/Logs/Synergy/synergy-server.log"
STATE_DIR = Path.home() / ".local/state"
STATE_DIR.mkdir(parents=True, exist_ok=True)
STATE_FILE = STATE_DIR / "synergy-rcmd-focus.state"

KEYCHRON_ON = (
    '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x7000000E7,'
    '"HIDKeyboardModifierMappingDst":0x7000000E0,'
    '"VendorID":13364,"ProductID":53297}]}'
)
KEYCHRON_OFF = '{"UserKeyMapping":[]}'

LINUXCLIENT = "linuxclient"
MAC = "mac-main"


def set_mapping(payload: str) -> None:
    subprocess.run(
        ["/usr/bin/hidutil", "property", "--set", payload],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def write_state(name: str) -> None:
    STATE_FILE.write_text(name + "\n")


def current_from_tail() -> str | None:
    if not LOG.exists():
        return None
    try:
        # last 80 lines is enough; switches are frequent
        out = subprocess.check_output(["/usr/bin/tail", "-n", "80", str(LOG)], text=True)
    except subprocess.CalledProcessError:
        return None
    last = None
    for line in out.splitlines():
        if 'switch from "' not in line or " to \"" not in line:
            continue
        # INFO: switch from "A" to "B" at ...
        try:
            dest = line.split(' to "', 1)[1].split('"', 1)[0]
        except IndexError:
            continue
        last = dest
    return last


def follow():
    dest = current_from_tail()
    mapped = dest == LINUXCLIENT
    set_mapping(KEYCHRON_ON if mapped else KEYCHRON_OFF)
    write_state(dest or "unknown")

    # Poll rather than inotify: Synergy appends frequently and poll is enough.
    pos = LOG.stat().st_size if LOG.exists() else 0
    while True:
        time.sleep(0.15)
        if not LOG.exists():
            continue
        size = LOG.stat().st_size
        if size < pos:
            pos = 0
        if size == pos:
            continue
        with LOG.open("r", errors="replace") as fh:
            fh.seek(pos)
            chunk = fh.read()
            pos = fh.tell()
        for line in chunk.splitlines():
            if 'switch from "' not in line or " to \"" not in line:
                continue
            try:
                dest = line.split(' to "', 1)[1].split('"', 1)[0]
            except IndexError:
                continue
            want = dest == LINUXCLIENT
            if want != mapped:
                set_mapping(KEYCHRON_ON if want else KEYCHRON_OFF)
                mapped = want
                write_state(dest)


if __name__ == "__main__":
    follow()
