# CLI / terminal application inventory (source machine snapshot)

Captured live 2026-08-10 from the user account. This is the CURRENT
application set behind the tmux / nvim / zsh stack. Version numbers are the
live `--version` output at capture time; they are a source snapshot, NOT a
mandate for every target to match.

## Core stack versions
| Tool | Version | Notes |
|------|---------|-------|
| zsh  | 5.9 (arm64-apple-darwin25.0) | macOS default shell |
| tmux | 3.6a | prefix C-a; window manager inside Terminal |
| neovim | v0.12.3 | /opt/homebrew/bin/nvim |
| fzf  | 0.74.1 | SHADOWED in ~/.local/bin (shadows brew 0.33.0) |
| git  | 2.50.1 (Apple Git-155) | system git |
| gh   | 2.88.1 | GitHub CLI |
| ranger | 1.9.4 | file manager |
| glow | 2.1.2 | markdown renderer |
| ripgrep | 15.1.0 | rg |
| Claude Code | 2.1.226 | ~/.local/bin/claude -> ~/.local/share/claude/versions/2.1.226 |
| Python | 3.13.13 (framework) | /Library/Frameworks/Python.framework |

## tmux plugin set (installed via TPM - NOT committed to this repo; install.sh clones + re-applies hooks)
| Plugin | Purpose | Source rev |
|--------|---------|-----------|
| tpm | tmux plugin manager | 99469c4 |
| tmux-sensible | sane defaults | 25cb91f |
| tmux-resurrect | session save/restore (the "save & restore" app) | cff343c |
| tmux-continuum | auto-save 15min + auto-restore + boot on login | 0698e8f |

Custom-local files that extend resurrect/continuum (committed here, re-copied
into the plugin dirs by install.sh because a TPM/plugin update overwrites them):
- tmux/resurrect-save-strategy/hermes_agents.sh      -> plugin save_command_strategies/
- tmux/resurrect-helpers/hermes_history_after_restore.sh -> plugin scripts/
- tmux/scripts/save_terminal_geometry.sh             -> ~/.tmux/scripts/
- tmux/LaunchAgents/Tmux.Start.plist                 -> ~/Library/LaunchAgents/ (continuum boot)

## Neovim plugins (lazy.nvim; pinned in nvim/lazy-lock.json - committed)
nvim-treesitter, render-markdown.nvim, obsidian.nvim,
nvim-treesitter -> nvim-web-devicons, nvim-tree.lua, lazy.nvim

## ~/.local/bin shadow / launcher installs
Shadow binaries and launchers (this dir is FIRST in PATH via .zshrc line 1).
Only some are committed (as @HOME@ templates in apps/local-bin/); binaries and
versioned installs are rebuilt on target:
| Entry | Type | Committed? |
|-------|------|-----------|
| fzf 0.74.1 | release binary (brew-blocked shadow install) | no - install via scripts/install-fzf-release.sh |
| claude -> ~/.local/share/claude/versions/2.1.226 | symlink to versioned install | no - native install |
| cua-driver | symlink to /Applications/CuaDriver.app | no - app install |
| hermes | launcher | yes (template) |
| profile shims | profile shims | yes (templates) |
| hermes-acp | ACP launcher | yes (template) |
| fonttoggle | Terminal font shrink/restore | yes |
| hermes-update-safe | update utility (patch-aware) | yes (profile-specific; review before use) |

## Brew packages (full lists committed; core interactive-shell ones highlighted)
- formulas: apps/brew-formulas.txt
- casks:    apps/brew-casks.txt
- Key casks for this stack: font-hack-nerd-font (Hack Nerd Font Mono, size 10 on
  Basic profile), alt-tab, dozer, easy-move+resize.
- Brew prefix /opt/homebrew is NOT writable by this user and has no passwordless
  sudo, so `brew install/upgrade` fails here. Workaround: shadow-install release
  binaries to ~/.local/bin (the fzf case) instead of fighting Homebrew perms.

## Terminal.app
- Profile "Basic" is the default and the one this stack uses.
- Option-as-Meta = ON (required for Alt-C fzf directory jumper / vi alt keys).
- Default window 271 x 150 cols/rows; font Hack Nerd Font Mono Regular size 10.
- Full importable profile: terminal/Basic.terminal (double-click to import).
- fonttoggle helper toggles Basic font size to 8 and back.

## Explicitly NOT in this repo (security / per-machine / out of scope)
- macOS keyboard REMAPPING layer (hidutil / ByHost / com.user.leftcmd-backspace
  LaunchAgent / Caps->Esc) - intentionally excluded; synced elsewhere.
- Hermes profile configs (profile config.yaml contain provider/API keys),
  ~/.hermes, .env, auth.json, state.db, sessions, memories, history.
- ~/.claude/.credentials.json (secrets).
- git identity (see .gitconfig.example in docs/ - set per machine).
- SSH keys, tokens, OAuth credentials - re-entered per target.
