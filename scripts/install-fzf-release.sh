#!/usr/bin/env bash
# install-fzf-release.sh - shadow-install a recent fzf release into ~/.local/bin
# when Homebrew is not writable (root-owned /opt/homebrew, no sudo). This PATH
# (first in .zshrc) shadows the older brew fzf.
#
# Needs: fzf >= 0.48 for the `fzf --zsh` integration, >= 0.35 for --scheme=path.
# The .zshrc in this repo expects >= 0.48. Default installs 0.74.1 (the source
# machine's pinned version override). Run again to re-pin after a future bump.
set -euo pipefail

VERSION="${1:-0.74.1}"
DEST="${HOME}/.local/bin"
mkdir -p "$DEST"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS/$ARCH" in
  Darwin/arm64)  FILENAME="fzf-${VERSION}-darwin_arm64.tar.gz" ;;
  Darwin/x86_64) FILENAME="fzf-${VERSION}-darwin_amd64.tar.gz" ;;
  Linux/x86_64)  FILENAME="fzf-${VERSION}-linux_amd64.tar.gz" ;;
  Linux/aarch64) FILENAME="fzf-${VERSION}-linux_arm64.tar.gz" ;;
  *) echo "unsupported: $OS/$ARCH" >&2; exit 1 ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/junegunn/fzf/releases/download/v${VERSION}/${FILENAME}"
echo "Fetching ${URL}"
curl -fsSL -o "$TMP/f.tar.gz" "$URL"
tar -xzf "$TMP/f.tar.gz" -C "$TMP"

# The tarball contains the bare `fzf` binary.
install -m 0755 "$TMP/fzf" "$DEST/fzf"
echo "Installed $($DEST/fzf --version) -> $DEST/fzf"
