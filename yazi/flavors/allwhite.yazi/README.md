# All White

A minimal Yazi flavor that renders every file and directory name in
bright white so the highlighted/hovered row is always legible, dropping
yazi's default type color-coding.

All other Yazi UI components (status bar, borders, tabs, mode badges,
etc.) keep Yazi's built-in defaults.

## Usage

In `~/.config/yazi/theme.toml`:

```toml
[flavor]
dark  = "allwhite"
light = "allwhite"
```

## What it changes

`[filetype].rules`:
- `{ url = "*",  fg = "white" }`  — all regular files
- `{ url = "*/", fg = "white" }`  — all directories
