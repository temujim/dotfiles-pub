# mac-dotfiles — terminal/agentic stack for macOS

Consolidated, canonical setup for the user Mac terminal stack: **tmux
(prefix C-a) + session save/restore (tmux-resurrect/continuum), zsh vi-mode +
autocomplete stack (fzf/autosuggestions/highlighting), Neovim (single-file
init.lua + lazy.nvim), Claude Code CLI, and the CLI app inventory.**

Live files on this Mac are the source of truth; this repo is their single
consolidated copy so the whole stack can be pulled onto another Mac laptop.

## What's inside
```
home/            .zshrc  .zprofile  .tmux.conf  .tmux-status.conf   (copy to ~)
nvim/            init.lua + lazy-lock.json        (copy to ~/.config/nvim/)
yazi/            keymap.toml + theme.toml         (copy to ~/.config/yazi/)
tmux/            resurrect save-strategy + helpers + scripts + LaunchAgent
apps/claude/     settings.json + keybindings.json (copy to ~/.claude/)
apps/local-bin/  launcher/profile-shim templates (@HOME@ = your home)
apps/            brew-formulas.txt  brew-casks.txt
terminal/        Basic.terminal     (importable Terminal.app profile)
scripts/         install-fzf-release.sh  install.sh  verify.sh
docs/            KEYMAPS.md  SETUP-ORDER.md  CLI-INVENTORY.md  SOURCES.md
legacy/          system-vim .vimrc (kept, NOT installed by default)
```

## Install on a new Mac
```bash
git clone <your-remote-url> ~/dotfiles-mac && cd ~/dotfiles-mac
bash scripts/install.sh          # copies dotfiles, writes launchers, reapplies tmux hooks
bash scripts/verify.sh           # QA probes (expected: all PASS)
```
Then follow docs/SETUP-ORDER.md for the manual bits TPM/terminal/Claude/Hermes
can't automate (font install, terminal import, plugin install, sign-ins).

## Key facts (details: docs/KEYMAPS.md)
- tmux prefix **C-a**; h/j/k/l pane nav; H/J/K/L resize; `C-s` save / `C-r` restore sessions.
- tmux save/restore = **tmux-resurrect + tmux-continuum** (+ custom `hermes_agents`
  restore strategy that turns Hermes/Claude panes back into resumable commands).
- zsh **vi-mode** (Esc = normal), fzf **Ctrl-R / Ctrl-T / Alt-C**, autosuggest **Right / Ctrl-F**.
- nvim lead key **Space**; **Space e** file explorer, **Space mv** Markdown render toggle.
- yazi file manager: `y`/`yy` cd-on-quit wrapper, `!` = drop to shell in CWD, all-white theme.
- Claude Code **editorMode vim**, fullscreen TUI, opus model.

## Scope & security (read docs/SOURCES.md)
- EXCLUDED on purpose: the **macOS keyboard remapping** layer (hidutil/ByHost/
  LeftCmd-Backspace/Caps→Esc) — it is synced from a separate file. Also excluded:
  Hermes profile configs & secrets, ~/.claude credentials, SSH/API keys, git identity.
- Committed as @HOME@ templates so they install correctly under ANY account name.

## Status
Initial local commit only. **No remote / NOT pushed** — add a remote when ready
(`git remote add origin <url>` then `git push -u origin main`).
