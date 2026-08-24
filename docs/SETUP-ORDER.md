# Fresh-Mac Setup Order

Hand this to an agent (or follow it) to reproduce the terminal/agentic stack on
a NEW Macbook account from this repo alone. It mirrors the "Titan Agentic
Workflow" install order (PrivateVault vault §2/§15) but reads the ACTUAL configs from
this repo as canonical. Every step that touches an existing target file takes a
dated backup first and offers a rollback (the porting review in the PrivateVault vault
"macOS Account Porting and Drift Review" applies).

Prereqs: macOS, an account with `whoami` = you, and this repo cloned somewhere.

## 0. Baseline
1. `bash scripts/install-fzf-release.sh` (shadow fzf >= 0.48 into ~/.local/bin)
   only if Homebrew is unavailable/blocked; otherwise `brew install fzf` is fine.
2. Install core tools (brew or release): tmux, neovim, gh, ranger, glow, ripgrep,
   tree, zsh-autosuggestions, zsh-completions, zsh-syntax-highlighting.
   Install the Hack Nerd Font (cask font-hack-nerd-font or download) into ~/Library/Fonts.
3. Install Terminal.app profile: open terminal/Basic.terminal (double-click →
   Import). Verify Option-as-Meta = ON for the "Basic" profile.
4. git identity: copy docs/.gitconfig.example → ~/.gitconfig and set your name/email.

## 1. zsh
Install script step copies home/.zshrc + home/.zprofile into ~, then validates:
- `zsh -n ~/.zshrc`
- `zsh -ic 'command -v fzf; fzf --version; bindkey -M viins "^R"; bindkey -M viins "^F"'`
Expected: fzf resolves (0.74.1+), ^R → fzf-history-widget, ^F → forward-char.
- `exec zsh -l` in the active terminal to pick up vi-mode + autocomplete.
Also: barrier — /opt/homebrew may be root-owned; `.zshrc` uses `compinit -u`.

## 2. tmux (PRIORITY)
1. install.sh writes home/.tmux.conf + home/.tmux-status.conf → ~.
2. Clone TPM: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`
3. Install plugins headless: `~/.tmux/plugins/tpm/bin/install_plugins`
   (installs tmux-sensible, tmux-resurrect, tmux-continuum).
4. install.sh re-applies the LOCAL custom files into the plugin dirs (a plugin
   update would otherwise overwrite them):
   - tmux/resurrect-save-strategy/hermes_agents.sh → ~/.tmux/plugins/tmux-resurrect/save_command_strategies/
   - tmux/resurrect-helpers/hermes_history_after_restore.sh → ~/.tmux/plugins/tmux-resurrect/scripts/
   - tmux/scripts/save_terminal_geometry.sh → ~/.tmux/scripts/
5. Boot LaunchAgent (continuum auto-restore on login): copy
   tmux/LaunchAgents/Tmux.Start.plist → ~/Library/LaunchAgents/ then
   `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/Tmux.Start.plist`
   (Linux: skip continuum-boot).
6. Reload + verify:
   - `tmux source-file ~/.tmux.conf`
   - `tmux show -g prefix`  → C-a
   - `tmux show -g @resurrect-save-command-strategy` → hermes_agents
   - Start a session, `prefix C-s` (save) then `prefix C-r` (restore) to test.
   tpm does NOT live in this repo (it's a git clone); .tmux.conf's final `run` line
   sources it — that line MUST stay last.

## 3. Neovim
1. install.sh writes nvim/init.lua + nvim/lazy-lock.json → ~/.config/nvim/.
2. Launch `nvim` once (headless bootstraps lazy.nvim), then install plugins
   SCOPED (lazy.nvim self-installs from init.lua specs):
   `nvim --headless "+Lazy! install nvim-treesitter render-markdown.nvim nvim-web-devicons nvim-tree.lua obsidian.nvim" +qa`
3. Verify: `nvim --headless "+qall"` (clean) and
   `nvim --headless -c "NvimTreeToggle" -c "lua print(require('nvim-tree.api').tree.is_visible())" -c "qa!"`
   → expect `true`.
4. Sanity: `Space e` toggles the sidebar.
Note: init.lua pins obsidian.nvim workspace to /Users/Shared/PrivateVault-SecondBrain —
point at your own vault path if different (and honor the profile routing rule:
never route profile captures to PrivateVault).

## 4. Claude Code
1. `npm i -g @anthropic-ai/claude-code` (or native installer), then
   `claude --version`.
2. install.sh writes apps/claude/settings.json + keybindings.json → ~/.claude/.
3. Launch once + sign in (credentials are NOT in this repo).
4. Verify: `claude --version`; `~/.claude` settings show editorMode vim.

## 4b. Yazi (file manager)
1. Shadow-install the yazi release binary → `~/.local/bin/yazi` (Homebrew perms
   block `brew install`; see TAW / scripts).
2. install.sh writes yazi/keymap.toml + theme.toml → ~/.config/yazi/.
3. The `y`/`yy` zsh wrapper (already in home/.zshrc) makes quitting cd the shell.
4. Verify: `y /tmp`, press `!` → shell at /tmp; `exit` → back in yazi. Theme
   renders all-white regardless of terminal dark/light mode.

## 5. Hermes / agents (optional, outside the tmux/nvim/terminal scope)
Hermes checkout, venv, profile homes and all provider keys/skin state are per
machine and NOT in this repo (secrets!). Recreate config per the TAW §7 runbook;
re-enter API keys; re-apply local patches only with their markers + rollback.
Local launchers (apps/local-bin/*) are templates — install.sh rewrites @HOME@
to your home; the profile shims (local, example, ...) point at your Hermes.

## 6. Final acceptance (run verify.sh after install)
- zsh -n ~/.zshrc
- zsh -ic binding dump (^R/^F/^T/Alt-C)
- tmux show -g prefix / borders / resurrect strategy; prefix C-s→C-r cycle
- nvim headless probes + Space e
- claude --version + editorMode vim

EXCLUDED BY DESIGN (do not expect here): the macOS keyboard remap layer
(hidutil/ByHost/LeftCmd-Backspace) — synced from a separate file.
