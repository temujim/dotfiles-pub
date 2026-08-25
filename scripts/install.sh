#!/usr/bin/env bash
# install.sh - apply this dotfiles repo to a macOS account (home = $HOME).
# Idempotent, backup-aware. Supports a sandbox home for testing via --prefix.
#
# Usage:
#   bash scripts/install.sh                 # install into $HOME
#   bash scripts/install.sh --prefix /tmp/fake   # install into a test home
#   bash scripts/install.sh --dry-run           # show actions, change nothing
#   bash scripts/install.sh --no-tpm            # skip tmux plugin clone/install
#   bash scripts/install.sh --with-fzf          # also shadow-install fzf release
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${HOME}"
DRY=0
DO_TPM=1
DO_FZF=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --no-tpm) DO_TPM=0; shift ;;
    --with-fzf) DO_FZF=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

TARGET_HOME="$PREFIX"
TS="$(date +%Y%m%d-%H%M%S)"
say()  { printf '  %s\n' "$*"; }
note() { printf '[install] %s\n' "$*"; }

# ---- helpers ----
backup_if_exists() {  # backup_if_exists <file>
  if [[ -e "$1" && ! -L "$1" ]]; then
    local b="$1.bak-$TS"
    cp -p "$1" "$b" && note "backed up $1 -> $b"
  fi
}
install_file() {  # install_file <src> <dst>   (copies, preserving mode)
  backup_if_exists "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -p "$src" "$dst"
  note "installed $dst"
}

if [[ "$DRY" -eq 1 ]]; then
  note "DRY-RUN (no changes). Target home = $TARGET_HOME"
fi

note "==> Applying stack to home: $TARGET_HOME"

# ---- 1. home dotfiles ----
note "--- dotfiles (zsh / zprofile / tmux) ---"
for f in .zshrc .zprofile .tmux.conf .tmux-status.conf; do
  src="$REPO_DIR/home/$f"
  dst="$TARGET_HOME/$f"
  [[ -f "$src" ]] || { note "SKIP missing source $f"; continue; }
  if [[ "$DRY" -eq 1 ]]; then say "would install $f -> $dst"; else install_file "$src" "$dst"; fi
done

# ---- 2. neovim ----
note "--- neovim config ---"
for f in init.lua lazy-lock.json; do
  src="$REPO_DIR/nvim/$f"; dst="$TARGET_HOME/.config/nvim/$f"
  [[ -f "$src" ]] || continue
  if [[ "$DRY" -eq 1 ]]; then say "would install nvim/$f -> $dst"; else install_file "$src" "$dst"; fi
done

# ---- 2b. yazi (keymap + flavor-based theme) ----
note "--- yazi config (keymap + theme + flavors) ---"
for f in keymap.toml theme.toml; do
  src="$REPO_DIR/yazi/$f"; dst="$TARGET_HOME/.config/yazi/$f"
  [[ -f "$src" ]] || continue
  if [[ "$DRY" -eq 1 ]]; then say "would install yazi/$f -> $dst"; else install_file "$src" "$dst"; fi
done
# flavors/ (all bundled yazi themes incl. custom allwhite)
for d in "$REPO_DIR"/yazi/flavors/*.yazi; do
  [[ -d "$d" ]] || continue
  name="$(basename "$d")"
  dst="$TARGET_HOME/.config/yazi/flavors/$name"
  if [[ "$DRY" -eq 1 ]]; then
    say "would install yazi/flavors/$name -> $dst"
  else
    mkdir -p "$dst"
    cp -a "$d"/. "$dst"/
    note "installed $dst"
  fi
done

# ---- 3. local-bin launchers (@HOME@ -> target home) ----
note "--- ~/.local/bin launchers (rewrites @HOME@) ---"
mkdir -p "$TARGET_HOME/.local/bin"
for src in "$REPO_DIR"/apps/local-bin/*; do
  [[ -f "$src" ]] || continue
  name="$(basename "$src")"
  dst="$TARGET_HOME/.local/bin/$name"
  if [[ "$DRY" -eq 1 ]]; then
    say "would write launcher $name (with home=$TARGET_HOME)"
  else
    if [[ "$name" == "hermes-update-safe" || "$name" == "fonttoggle" ]]; then
      cp -p "$src" "$dst"          # self-contained (uses $HOME/~, no @HOME@)
    else
      sed "s|@HOME@|$TARGET_HOME|g" "$src" > "$dst"   # templated launcher/shims (incl. hermes-acp)
    fi
    chmod +x "$dst"
    note "wrote launcher $TARGET_HOME/.local/bin/$name"
  fi
done

# ---- 4. claude app config ----
note "--- claude code settings/keybindings ---"
for f in settings.json keybindings.json; do
  src="$REPO_DIR/apps/claude/$f"; dst="$TARGET_HOME/.claude/$f"
  if [[ "$DRY" -eq 1 ]]; then say "would install claude/$f"; else install_file "$src" "$dst"; fi
done

# ---- 5. tmux plugins + custom hooks ----
note "--- tmux (TPM + plugins + local resurrect hooks) ---"
TMUX_DIR="$TARGET_HOME/.tmux"
TPM_DIR="$TMUX_DIR/plugins/tpm"

if [[ "$DO_TPM" -eq 1 ]]; then
  if [[ "$DRY" -eq 1 ]]; then
    say "would clone TPM -> $TPM_DIR and install plugins"
  else
    mkdir -p "$TMUX_DIR/plugins"
    if [[ ! -d "$TPM_DIR/.git" ]]; then
      note "cloning TPM..."
      git clone -q https://github.com/tmux-plugins/tpm "$TPM_DIR"
    else
      note "TPM already present"
    fi
    # Unattended plugin install (tmux-sensible, resurrect, continuum) via TPM.
    note "installing tmux plugins (tpm bin/install_plugins)..."
    "$TPM_DIR/bin/install_plugins" || note "plugin install returned non-zero (check net/TPM)"
  fi
fi

# Re-copy LOCAL custom files into the plugin tree (a plugin update would wipe them).
hook() {  # hook <repo-rel> <home-rel>
  local src="$REPO_DIR/$1" dst="$TARGET_HOME/$2"
  if [[ -f "$src" ]]; then
    if [[ "$DRY" -eq 1 ]]; then say "would re-apply $1 -> $2"; else install_file "$src" "$dst"; fi
  fi
}
hook "tmux/resurrect-save-strategy/hermes_agents.sh"         ".tmux/plugins/tmux-resurrect/save_command_strategies/hermes_agents.sh"
hook "tmux/resurrect-helpers/hermes_history_after_restore.sh" ".tmux/plugins/tmux-resurrect/scripts/hermes_history_after_restore.sh"
hook "tmux/scripts/save_terminal_geometry.sh"                 ".tmux/scripts/save_terminal_geometry.sh"

# ---- 6. tmux continuum boot LaunchAgent ----
note "--- tmux continuum boot LaunchAgent ---"
LA_SRC="$REPO_DIR/tmux/LaunchAgents/Tmux.Start.plist"
if [[ -f "$LA_SRC" ]]; then
  LA_DST="$TARGET_HOME/Library/LaunchAgents/Tmux.Start.plist"
  if [[ "$DRY" -eq 1 ]]; then
    say "would write LaunchAgent (with home=$TARGET_HOME) + print bootstrap cmd"
  else
    mkdir -p "$(dirname "$LA_DST")"
    sed "s|~|$TARGET_HOME|g" "$LA_SRC" > "$LA_DST"
    chmod 644 "$LA_DST"
    note "wrote $LA_DST"
    if [[ "$TARGET_HOME" == "$HOME" ]]; then
      note "to enable (auto-restore on login), run:"
      note "  launchctl bootstrap gui/\$(id -u) $LA_DST"
    else
      note "(sandbox home: LaunchAgent NOT bootstrapped)"
    fi
  fi
fi

# ---- 7. optional fzf shadow-install ----
if [[ "$DO_FZF" -eq 1 ]]; then
  if [[ "$DRY" -eq 1 ]]; then say "would run scripts/install-fzf-release.sh"; else bash "$REPO_DIR/scripts/install-fzf-release.sh"; fi
fi

note "==> Done. Run: bash scripts/verify.sh [--prefix $PREFIX] for QA probes."
