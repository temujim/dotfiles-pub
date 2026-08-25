export PATH="$HOME/.local/bin:$PATH"
export SSL_CERT_FILE="$HOME/.config/last30days/ca-roots.pem"

# ---------------------------------------------------------------------------
# zsh autocomplete stack (brew: zsh-completions, zsh-autosuggestions,
# zsh-syntax-highlighting, fzf). Layout mirrors the profile-b 2026-06-19 setup.
# Keys: Tab=complete, Right/Ctrl-F=accept suggestion, Ctrl-R=fzf history,
#       Ctrl-T=fzf file picker, Alt-C=fzf directory jumper.
# ---------------------------------------------------------------------------
if [[ -o interactive ]]; then
  # Extra completion definitions (must be in fpath before compinit).
  if [[ -d /opt/homebrew/share/zsh-completions ]]; then
    fpath=(/opt/homebrew/share/zsh-completions $fpath)
  fi

  # -u: skip compaudit security check (Homebrew dirs are group-writable on
  # this Mac and chmod is not permitted for this user).
  autoload -Uz compinit && compinit -u

  # fzf priority folders: /Users/Shared (primary), then ~/Documents, then
  # ~/Agentic are listed BEFORE the cwd results. --tiebreak=index makes
  # earlier input lines win score ties, so equal-quality matches resolve
  # toward the priority folders. awk dedupes anything reachable from both.
  export FZF_CTRL_T_COMMAND='
    { find /Users/Shared "$HOME/Documents" "$HOME/Agentic" -type f 2>/dev/null
      find . -type f -not -path "*/.git/*" 2>/dev/null
    } | awk "!seen[\$0]++"'
  export FZF_CTRL_T_OPTS='--scheme=path --tiebreak=index'
  export FZF_ALT_C_COMMAND='
    { find /Users/Shared "$HOME/Documents" "$HOME/Agentic" -type d 2>/dev/null
      find . -type d -not -path "*/.git/*" 2>/dev/null
    } | awk "!seen[\$0]++"'
  export FZF_ALT_C_OPTS='--scheme=path --tiebreak=index'

  # fzf: **<Tab> completion + Ctrl-R / Ctrl-T / Alt-C key bindings.
  [[ -f /opt/homebrew/opt/fzf/shell/completion.zsh ]] && source /opt/homebrew/opt/fzf/shell/completion.zsh
  [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]] && source /opt/homebrew/opt/fzf/shell/key-bindings.zsh

  # Gray inline history suggestions (accept with Right Arrow or Ctrl-F).
  [[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Hermes: zsh vi/vim command-line editing for interactive shells.
# - Esc switches to NORMAL mode; i/a/etc. return to INSERT.
# - KEYTIMEOUT=1 removes the default Esc delay.
# - Cursor shape changes in Terminal.app/iTerm-compatible terminals:
#   beam = INSERT, block = NORMAL, steady underline = REPLACE.
if [[ -o interactive && -z "${HERMES_ZSH_VI_MODE_DISABLE:-}" ]]; then
  bindkey -v
  export KEYTIMEOUT=1

  # Useful defaults that vi mode otherwise makes easy to lose.
  bindkey '^?' backward-delete-char
  bindkey -M viins '^R' history-incremental-search-backward
  bindkey -M vicmd '^R' history-incremental-search-backward
  bindkey -M vicmd 'u' undo
  bindkey -M vicmd '^T' redo

  # Visual mode cue: cursor shape follows the zle keymap.
  function _hermes_zsh_vi_cursor_shape() {
    case "$KEYMAP" in
      vicmd)      printf '\e[2 q' ;;  # block cursor: NORMAL
      viopp)      printf '\e[2 q' ;;  # block cursor: operator-pending
      visual)     printf '\e[2 q' ;;  # block cursor: visual
      replace*)   printf '\e[4 q' ;;  # underline cursor: REPLACE
      main|viins|*) printf '\e[6 q' ;; # beam cursor: INSERT
    esac
  }

  function zle-keymap-select() {
    _hermes_zsh_vi_cursor_shape
    zle reset-prompt
  }

  function zle-line-init() {
    _hermes_zsh_vi_cursor_shape
  }

  function zle-line-finish() {
    printf '\e[0 q'
  }

  zle -N zle-keymap-select
  zle -N zle-line-init
  zle -N zle-line-finish
fi

# Autocomplete-stack key fixes (must come AFTER the vi block, which rebinds ^R):
# - ^R -> fzf fuzzy history (restores the documented stack behavior).
# - ^F -> forward-char, so it accepts the gray autosuggestion (home-row accept).
# Right Arrow already accepts via vi-forward-char (in autosuggest accept list).
if [[ -o interactive ]]; then
  if (( $+widgets[fzf-history-widget] )); then
    bindkey -M viins '^R' fzf-history-widget
    bindkey -M vicmd '^R' fzf-history-widget
  fi
  bindkey -M viins '^F' forward-char
fi

# Yazi wrapper: cd to current working directory on exit
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	command rm -f -- "$tmp"
}

# zsh-syntax-highlighting MUST be sourced last (after all widgets/keybindings).
if [[ -o interactive && -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
