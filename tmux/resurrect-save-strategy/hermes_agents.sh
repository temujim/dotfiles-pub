#!/usr/bin/env bash
set -euo pipefail

# tmux-resurrect custom save strategy for Hermes/Claude panes.
# Based on profile-b's tmux restore implementation: inspect the full pane process
# tree, then save exact agent resume commands instead of generic Python/shell
# commands.

PANE_PID="${1:-}"
DEFAULT_STRATEGY="$HOME/.tmux/plugins/tmux-resurrect/save_command_strategies/ps.sh"

[ -n "$PANE_PID" ] || exit 0

python3 - "$PANE_PID" "$DEFAULT_STRATEGY" <<'PY'
import datetime
import glob
import os
import re
import shlex
import sqlite3
import subprocess
import sys
from pathlib import Path

pane_pid = int(sys.argv[1])
default_strategy = sys.argv[2]
home = Path.home()
self_pid = os.getpid()


def run(cmd):
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)


def shell_quote_list(parts):
    return ' '.join(shlex.quote(str(p)) for p in parts if str(p) != '')


def parse_args(cmd):
    try:
        return shlex.split(cmd)
    except Exception:
        return cmd.split()


def exe_basename(argv):
    if not argv:
        return ''
    return os.path.basename(argv[0])


def is_wrapper_noise(cmd):
    # When the strategy is tested from inside a live Hermes pane, the pane has
    # descendant bash/python processes running this strategy. Do not let those
    # command lines falsely match old literal strings like "hermes --resume".
    noise = (
        'save_command_strategies/hermes_agents.sh',
        'tmux-resurrect/scripts/save.sh',
        'hermes-snap-',
        '__HERMES_CWD_',
    )
    return any(s in cmd for s in noise)


def is_hermes_argv(argv):
    if not argv:
        return False
    base = exe_basename(argv)
    if base == 'hermes':
        return True
    # Python app wrapper used by local Hermes installs:
    #   Python .../venv/bin/hermes [args]
    if 'python' in base.lower():
        return any(os.path.basename(a) == 'hermes' or a.endswith('/bin/hermes') for a in argv[1:4])
    return False


def is_claude_argv(argv):
    if not argv:
        return False
    if exe_basename(argv) == 'claude' or any(os.path.basename(a) == 'claude' for a in argv[:3]):
        return True
    # Versioned binary: ~/.local/share/claude/versions/X.Y.Z (Mach-O) resolved from symlink
    # e.g. ~/.local/share/claude/versions/2.1.286 --resume <uuid>
    # basename is version number, not 'claude', so check path contains /claude/
    for a in argv[:3]:
        if '/claude/versions/' in a or '/.claude/' in a:
            return True
        # e.g. basename 2.1.286 with path containing claude
        if re.fullmatch(r'\d+\.\d+\.\d+', os.path.basename(a)) and 'claude' in a.lower():
            return True
    return False


def arg_value(argv, names):
    names = set(names)
    for i, arg in enumerate(argv):
        if arg in names and i + 1 < len(argv):
            return argv[i + 1]
        for name in names:
            if arg.startswith(name + '='):
                return arg.split('=', 1)[1]
    return None


def profile_from_argv(argv):
    return arg_value(argv, ('--profile', '-p'))


def resume_from_argv(argv):
    return arg_value(argv, ('--resume', '-r'))


def ps_rows():
    out = run(['ps', '-ax', '-o', 'pid=', '-o', 'ppid=', '-o', 'lstart=', '-o', 'command='])
    rows = []
    # lstart is 5 fields, e.g. Fri Jul 17 10:24:57 2026
    for line in out.splitlines():
        parts = line.strip().split(None, 7)
        if len(parts) < 8:
            continue
        try:
            pid, ppid = int(parts[0]), int(parts[1])
        except ValueError:
            continue
        lstart_s = ' '.join(parts[2:7])
        cmd = parts[7]
        start = 0.0
        for fmt in ('%a %d %b %H:%M:%S %Y', '%a %b %d %H:%M:%S %Y'):
            try:
                start = datetime.datetime.strptime(lstart_s, fmt).timestamp()
                break
            except Exception:
                pass
        rows.append((pid, ppid, start, cmd))
    return rows


rows = ps_rows()
by_pid = {r[0]: r for r in rows}
children = {}
for pid, ppid, start, cmd in rows:
    children.setdefault(ppid, []).append(pid)


def descendants(root):
    q = list(children.get(root, []))
    out = []
    seen = set()
    while q:
        pid = q.pop(0)
        if pid in seen:
            continue
        seen.add(pid)
        row = by_pid.get(pid)
        if row:
            out.append(row)
            q.extend(children.get(pid, []))
    return out


desc = [r for r in descendants(pane_pid) if r[0] != self_pid and not is_wrapper_noise(r[3])]


def fallback():
    os.execv(default_strategy, [default_strategy, str(pane_pid)])


def pane_cwd():
    try:
        out = run(['tmux', 'list-panes', '-a', '-F', '#{pane_pid}\t#{pane_current_path}'])
        for line in out.splitlines():
            pid_s, cwd = line.split('\t', 1)
            if pid_s == str(pane_pid):
                return cwd
    except Exception:
        pass
    return os.getcwd()


# 1) If an exact Hermes/Claude resume command is already the real process,
# normalize and keep it.
# local patch 2026-09-25: a BARE `hermes --resume <sid>` argv (profile omitted)
# is only re-saved bare when the session actually exists in the default-home
# state.db. Otherwise resolve which profile DB holds the session and emit
# `--profile <p>` — otherwise a restored pane looks in the default DB, prints
# "Session not found", and boots an empty chat (/history shows nothing).
# Rollback: cp hermes_agents.sh.bak-20260925 over this file.
def default_db_has_session(sid):
    db = home / '.hermes' / 'state.db'
    if not db.exists():
        return False
    try:
        con = sqlite3.connect(str(db))
        row = con.execute('select 1 from sessions where id=?', (sid,)).fetchone()
        con.close()
    except Exception:
        return False
    return bool(row)


def profile_holding_session(sid):
    for db in sorted((home / '.hermes' / 'profiles').glob('*/state.db')):
        try:
            con = sqlite3.connect(str(db))
            row = con.execute('select 1 from sessions where id=?', (sid,)).fetchone()
            con.close()
        except Exception:
            continue
        if row:
            return db.parent.name
    return None


for _pid, _ppid, _start, cmd in desc:
    argv = parse_args(cmd)
    if is_hermes_argv(argv):
        sid = resume_from_argv(argv)
        if sid:
            profile = profile_from_argv(argv)
            if profile is None and not default_db_has_session(sid):
                profile = profile_holding_session(sid)
            parts = ['hermes']
            if profile:
                parts += ['--profile', profile]
            parts += ['--resume', sid]
            print(shell_quote_list(parts))
            sys.exit(0)
    if is_claude_argv(argv):
        sid = resume_from_argv(argv)
        if sid and re.fullmatch(r'[0-9a-fA-F-]{36}', sid):
            print(shell_quote_list(['claude', '--resume', sid]))
            sys.exit(0)


# 2) Bare Hermes pane: map by profile, cwd, and process start time to closest
# Hermes session in the right state DB.
def hermes_dbs(preferred_profile=None):
    yielded = set()
    def emit(prof, db):
        s = str(db)
        if s in yielded:
            return
        yielded.add(s)
        yield prof, db
    if preferred_profile:
        yield from emit(preferred_profile, home / '.hermes' / 'profiles' / preferred_profile / 'state.db')
    else:
        # Prefer profile DBs before the legacy default DB for profile-launched
        # Hermes panes whose command line did not expose profile cleanly.
        for db in sorted((home / '.hermes' / 'profiles').glob('*/state.db')):
            yield from emit(db.parent.name, db)
    yield from emit(None, home / '.hermes' / 'state.db')
    for db in sorted((home / '.hermes' / 'profiles').glob('*/state.db')):
        yield from emit(db.parent.name, db)


hermes_procs = []
for pid, ppid, start, cmd in desc:
    argv = parse_args(cmd)
    if is_hermes_argv(argv):
        hermes_procs.append((pid, start, cmd, profile_from_argv(argv)))

if hermes_procs:
    # Use the earliest actual Hermes process under the pane, not transient tool
    # subprocesses under it.
    _, proc_start, _, profile = sorted(hermes_procs, key=lambda x: x[1])[0]
    cwd = pane_cwd()
    candidates = []
    for prof, db in hermes_dbs(profile):
        if not db.exists():
            continue
        try:
            con = sqlite3.connect(str(db))
            rows = con.execute(
                "select id, started_at, ended_at, cwd from sessions where source='cli' order by started_at desc limit 500"
            ).fetchall()
            con.close()
        except Exception:
            continue
        for sid, started_at, ended_at, session_cwd in rows:
            if not started_at:
                continue
            cwd_bonus = 0 if (session_cwd and cwd and os.path.abspath(session_cwd) == os.path.abspath(cwd)) else 7200
            ended_bonus = 0 if ended_at is None else 86400
            profile_bonus = 0 if (profile is None or prof == profile) else 43200
            # A fresh interactive Hermes session may create its DB row a little
            # after process start. Give that normal delay no penalty.
            time_delta = abs(float(started_at) - proc_start)
            if float(started_at) >= proc_start and time_delta < 600:
                time_delta = 0
            score = time_delta + cwd_bonus + ended_bonus + profile_bonus
            candidates.append((score, prof, sid))
    if candidates:
        _score, prof, sid = sorted(candidates)[0]
        parts = ['hermes']
        if prof:
            parts += ['--profile', prof]
        parts += ['--resume', sid]
        print(shell_quote_list(parts))
        sys.exit(0)


# 3) Claude panes: map current cwd to Claude project JSONL and choose the most
# recent concrete UUID, including Claude Code worktree key variants.
def claude_project_key(path):
    path = os.path.abspath(path)
    return path.replace('/', '-')


claude_procs = []
for pid, ppid, start, cmd in desc:
    argv = parse_args(cmd)
    if is_claude_argv(argv):
        claude_procs.append((pid, start, cmd))

if claude_procs:
    cwd = pane_cwd()
    keys = [claude_project_key(cwd)]
    if '/.claude/worktrees/' in cwd:
        repo, rest = cwd.split('/.claude/worktrees/', 1)
        name = rest.split('/', 1)[0]
        keys.insert(0, claude_project_key(repo) + '--claude-worktrees-' + name)
    for key in keys:
        files = sorted(glob.glob(str(home / '.claude' / 'projects' / key / '*.jsonl')), key=os.path.getmtime, reverse=True)
        for f in files:
            uuid = Path(f).stem
            if re.fullmatch(r'[0-9a-fA-F-]{36}', uuid):
                print(shell_quote_list(['claude', '--resume', uuid]))
                sys.exit(0)


# 4) Vim/Neovim command normalization for filenames with spaces.
for pid, ppid, start, cmd in desc:
    argv = parse_args(cmd)
    if argv and re.search(r'^(n?vim|view|vimdiff|nvim)$', os.path.basename(argv[0])):
        print(shell_quote_list(argv))
        sys.exit(0)

fallback()
PY
