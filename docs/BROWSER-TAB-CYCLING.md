# macOS Ctrl+Tab / Ctrl+Shift+Tab Browser Tab Cycling (native, no install)

Replicates Linux/Windows-style tab switching on macOS using native global App Shortcuts.
No Karabiner, no hidutil, no admin password needed. Applies to the current user account.

Tested working 2026-08-26 on Microsoft Edge and Chrome-family; Safari uses
"Show Next/Previous Tab" titles and is covered by the same setting below.

> This is a distinct layer from the hidutil/ByHost *hardware key remapping* (which the
> macos-keymap repo excludes and syncs separately). This is a **global App Shortcuts**
> binding (`defaults` → `NSUserKeyEquivalents`), written to the user's plist, and it is
> fully portable across macOS accounts by re-running the commands below.

## The core idea

macOS maps a key combo to a menu-item TITLE via the global `NSUserKeyEquivalents`
dictionary (`defaults` domain `-g`). When the frontmost app exposes a menu item whose
title matches, macOS rebinds that menu item to your combo — REPLACING its previous
shortcut.

Menu-item titles are per-browser:

| Browser family | Next tab menu title  | Previous tab menu title |
| :--- | :--- | :--- |
| Chrome / Edge / Brave / Arc / Opera / Vivaldi / Chromium | `Select Next Tab` | `Select Previous Tab` |
| Firefox | `Select Next Tab` | `Select Previous Tab` |
| Safari | `Show Next Tab` | `Show Previous Tab` |

## The key-combo encoding

`defaults` key-equivalent strings use prefix letters then the key:
- `^` = Control, `$` = Shift, `@` = Command, `~` = Option
- Tab key is a real TAB character, written as `\t` inside the shell-quoted string.

So:
- Ctrl+Tab          = `^\t`
- Ctrl+Shift+Tab    = `^$\t`
- (old ⌘2 / ⌘1)     = `@2` / `@1`) — these get replaced by the new bindings.

## The commands (run once per device)

```bash
# 1) Snapshot current settings first (rollback path)
mkdir -p ~/keyboard-backups
defaults export -g - > ~/keyboard-backups/GlobalPreferences-before-$(date +%Y%m%d-%H%M%S).plist

# 2) Apply the browser tab cycling shortcuts globally
defaults write -g NSUserKeyEquivalents -dict-add \
  "Select Next Tab"     "^\t" \
  "Select Previous Tab" "^$\t" \
  "Show Next Tab"       "^\t" \
  "Show Previous Tab"   "^$\t"

# 3) Verify stored bytes are a REAL tab (0x09), not a literal backslash-t
defaults read -g NSUserKeyEquivalents | cat -v

# 4) Show Keyboard Access must be OFF so macOS doesn't hijack Ctrl+Tab itself
defaults read -g AppleKeyboardUIMode   # want 0 or missing
```

## The critical gotchas

1. **RELAUNCH every browser.** Running apps built their menu before the change and will
   NOT pick it up. Quit (Cmd+Q) and reopen. Test in a NEW window.
   - Verify live: read the menu's actual key equivalent:
     ```applescript
     tell application "System Events"
       tell process "Chrome"
         repeat with mi in every menu item of menu 1 of menu bar item "Tab" of menu bar 1
           if name of mi is "Select Next Tab" or name of mi is "Select Previous Tab" then
             return name of mi & " => " & (value of attribute "AXMenuItemCmdChar" of mi)
           end if
         end repeat
       end tell
     end tell
     ```
     A `\t` in `AXMenuItemCmdChar` means the tab override is live. If you still see
     `1`/`2`, the app hasn't reloaded its menu yet.
2. **Global scope**: these bind to "Select Next/Previous Tab" in ANY app with that menu
   title — it is not browser-specific. For Chrome-family and Safari that is exactly the
   tab cycle. A few niche apps share the title but it is rare.
3. The existing built-in ⌘1/⌘2 (and any user defaults that mapped `Select Next Tab`/`@2`)
   are REPLACED, not kept. Rollback restores them via the snapshot + a `defaults
   write -g NSUserKeyEquivalents -dict ...` back to the original strings.
4. This is per-account. Run the same commands on each account you want it on.

## Rollback

Restore the snapshot you took in step 1:

```bash
# Re-import the full snapshot (returns ALL global app-key shortcuts to pre-change state)
defaults import -g ~/keyboard-backups/GlobalSettings-before-<ts>.plist
# or surgically: write -g NSUserKeyEquivalents -dict with the original @1/@2 entries
```

Then relaunch the browsers.

## Real-world notes (profile-b Mac, 2026-08-26)

Settings live in `.GlobalPreferences` / `NSUserKeyEquivalents`, applied via
`defaults write -g NSUserKeyEquivalents -dict-add` (not the System Settings panel).
Full Keyboard Access is OFF so no hijack; AltTab was checked and does not own Ctrl+Tab
(no conflict). A snapshot is at `~/keyboard-backups/appshortcuts-20260826-111311/`.