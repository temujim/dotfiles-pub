#!/usr/bin/env bash
# Pre-publish privacy and security gate.
# Verifies:
#   1. Script runs from within a valid Git repository root.
#   2. Working tree has no generic secrets (private keys, tokens, auth URLs).
#   3. Reachable history has no generic secrets.
#   4. Commit messages have no secrets.
#   5. All commit author/committer identities match the expected noreply email.
#   6. No leftover dangling original refs exist.
#   7. If a local private blocklist exists (or is required), scans against it.
set -u

# 1. Resolve and validate Git repository root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: Not inside a Git repository." >&2
  exit 1
}
cd "$REPO_ROOT" || {
  echo "ERROR: Failed to change to repository root: $REPO_ROOT" >&2
  exit 1
}

EXPECTED_EMAIL="${EXPECTED_EMAIL:-temujim@users.noreply.github.com}"
REQUIRE_BLOCKLIST="${REQUIRE_PRIVATE_BLOCKLIST:-0}"
for arg in "$@"; do
  case "$arg" in
    --require-blocklist)
      REQUIRE_BLOCKLIST=1
      ;;
  esac
done

fail=0

# Clean temporary files on exit
CLEAN_BLOCKLIST=""
cleanup() {
  if [ -n "$CLEAN_BLOCKLIST" ] && [ -f "$CLEAN_BLOCKLIST" ]; then
    rm -f "$CLEAN_BLOCKLIST"
  fi
}
trap cleanup EXIT INT TERM

# 2. Locate private blocklist if available (kept OUTSIDE public tracked files)
BLOCKLIST_FILE=""
if [ -n "${DOTFILES_PRIVATE_BLOCKLIST:-}" ] && [ -f "$DOTFILES_PRIVATE_BLOCKLIST" ]; then
  BLOCKLIST_FILE="$DOTFILES_PRIVATE_BLOCKLIST"
elif [ -f "$REPO_ROOT/.private-blocklist" ]; then
  BLOCKLIST_FILE="$REPO_ROOT/.private-blocklist"
elif [ -f "$HOME/.config/dotfiles/private-blocklist" ]; then
  BLOCKLIST_FILE="$HOME/.config/dotfiles/private-blocklist"
fi

if [ -n "$BLOCKLIST_FILE" ]; then
  CLEAN_BLOCKLIST="$(mktemp -t dotfiles-blocklist.XXXXXX 2>/dev/null || mktemp /tmp/dotfiles-blocklist.XXXXXX)"
  grep -v '^[[:space:]]*#' "$BLOCKLIST_FILE" | grep -v '^[[:space:]]*$' > "$CLEAN_BLOCKLIST" 2>/dev/null || true
  if [ -s "$CLEAN_BLOCKLIST" ]; then
    echo "-- [1/6] Private blocklist: ACTIVE ($BLOCKLIST_FILE) --"
  else
    rm -f "$CLEAN_BLOCKLIST"
    CLEAN_BLOCKLIST=""
    echo "-- [1/6] Private blocklist: Empty after comment stripping ($BLOCKLIST_FILE) --"
  fi
elif [ "$REQUIRE_BLOCKLIST" = "1" ]; then
  echo "FAIL: Required private blocklist file not found." >&2
  fail=1
else
  echo "-- [1/6] Private blocklist: None found (generic secrets & identities checked) --"
fi

# Generic secret patterns (standard security rules, no private identifiers)
# Note: use -e when passing patterns to grep because key patterns start with '-'
GENERIC_KEY_PATTERN='-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----'
GENERIC_TOKEN_PATTERN='\b(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{10,})\b'
GENERIC_AUTH_URL_PATTERN='\b(mysql|postgresql|postgres|mongodb|redis|amqp|mssql)://[^/[:space:]:@]+:[^/[:space:]:@]+@[^/[:space:]]+'

echo "-- [2/6] Working tree check --"
TRACKED_FILES="$(git ls-files 2>/dev/null)" || {
  echo "ERROR: Failed to list tracked files." >&2
  exit 1
}

while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ "$f" = "scripts/pre-publish-check.sh" ] && continue
  [ ! -f "$f" ] && continue

  if grep -E -q -e "$GENERIC_KEY_PATTERN" "$f" 2>/dev/null; then
    echo "FAIL: [private-key-header] in $f [content redacted]" >&2
    fail=1
  fi
  if grep -E -q -e "$GENERIC_TOKEN_PATTERN" "$f" 2>/dev/null; then
    echo "FAIL: [known-token-pattern] in $f [content redacted]" >&2
    fail=1
  fi
  if grep -E -q -e "$GENERIC_AUTH_URL_PATTERN" "$f" 2>/dev/null; then
    echo "FAIL: [authenticated-connection-url] in $f [content redacted]" >&2
    fail=1
  fi

  if [ -n "$CLEAN_BLOCKLIST" ] && [ -s "$CLEAN_BLOCKLIST" ]; then
    if grep -E -i -q -f "$CLEAN_BLOCKLIST" "$f" 2>/dev/null; then
      echo "FAIL: [private-blocklist] in $f [content redacted]" >&2
      fail=1
    fi
  fi
done <<< "$TRACKED_FILES"
[ "$fail" -eq 0 ] && echo "ok: working tree clean"

echo "-- [3/6] Reachable history check --"
GIT_DIFF_OUTPUT="$(git log --all -p 2>/dev/null)"
if [ $? -ne 0 ]; then
  echo "ERROR: git log failed while scanning history." >&2
  exit 1
fi

if printf "%s\n" "$GIT_DIFF_OUTPUT" | grep -E -q -e "$GENERIC_KEY_PATTERN"; then
  echo "FAIL: [private-key-header] found in reachable history [content redacted]" >&2
  fail=1
fi
if printf "%s\n" "$GIT_DIFF_OUTPUT" | grep -E -q -e "$GENERIC_TOKEN_PATTERN"; then
  echo "FAIL: [known-token-pattern] found in reachable history [content redacted]" >&2
  fail=1
fi
if printf "%s\n" "$GIT_DIFF_OUTPUT" | grep -E -q -e "$GENERIC_AUTH_URL_PATTERN"; then
  echo "FAIL: [authenticated-connection-url] found in reachable history [content redacted]" >&2
  fail=1
fi
if [ -n "$CLEAN_BLOCKLIST" ] && [ -s "$CLEAN_BLOCKLIST" ]; then
  if printf "%s\n" "$GIT_DIFF_OUTPUT" | grep -E -i -q -f "$CLEAN_BLOCKLIST"; then
    echo "FAIL: [private-blocklist] found in reachable history [content redacted]" >&2
    fail=1
  fi
fi
[ "$fail" -eq 0 ] && echo "ok: reachable history clean"

echo "-- [4/6] Commit messages check --"
GIT_MESSAGES="$(git log --all --format='COMMIT:%h%n%B%n' 2>/dev/null)"
if [ $? -ne 0 ]; then
  echo "ERROR: git log failed while scanning commit messages." >&2
  exit 1
fi

if printf "%s\n" "$GIT_MESSAGES" | grep -E -q -e "$GENERIC_TOKEN_PATTERN"; then
  echo "FAIL: [known-token-pattern] found in commit messages [content redacted]" >&2
  fail=1
fi
if printf "%s\n" "$GIT_MESSAGES" | grep -E -q -e "$GENERIC_AUTH_URL_PATTERN"; then
  echo "FAIL: [authenticated-connection-url] found in commit messages [content redacted]" >&2
  fail=1
fi
if [ -n "$CLEAN_BLOCKLIST" ] && [ -s "$CLEAN_BLOCKLIST" ]; then
  if printf "%s\n" "$GIT_MESSAGES" | grep -E -i -q -f "$CLEAN_BLOCKLIST"; then
    echo "FAIL: [private-blocklist] found in commit messages [content redacted]" >&2
    fail=1
  fi
fi
[ "$fail" -eq 0 ] && echo "ok: commit messages clean"

echo "-- [5/6] Commit author/committer identities check --"
ALL_IDENTITIES="$(git log --all --format='%ae%n%ce' 2>/dev/null | sort -u)"
if [ $? -ne 0 ]; then
  echo "ERROR: git log failed while scanning commit identities." >&2
  exit 1
fi

NON_CONFORMING="$(printf "%s\n" "$ALL_IDENTITIES" | grep -v '^$' | grep -Fxv "$EXPECTED_EMAIL" || true)"
if [ -n "$NON_CONFORMING" ]; then
  BAD_COUNT="$(printf "%s\n" "$NON_CONFORMING" | wc -l | tr -d ' ')"
  echo "FAIL: Non-conforming commit identity detected ($BAD_COUNT distinct address(es)) [address redacted]" >&2
  fail=1
else
  echo "ok: all commit identities match $EXPECTED_EMAIL"
fi

echo "-- [6/6] Leftover dangling refs check --"
if [ -d "$REPO_ROOT/.git/refs/original" ]; then
  echo "FAIL: .git/refs/original exists (leftover from history filtering)." >&2
  fail=1
else
  echo "ok: no dangling refs"
fi

if [ "$fail" -ne 0 ]; then
  echo "PRE-PUBLISH CHECK: FAILED" >&2
  exit 1
else
  echo "PRE-PUBLISH CHECK: PASS"
  exit 0
fi
