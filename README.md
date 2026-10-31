# `git-hunks.nvim`

A minimal plugin to view, navigate, and reset git hunks. Also includes a diff view for comparing any two git file locations.

## Features

- 1 source file (~500 LOC), no dependencies
- Async diff computation via coroutines (no UI freezing)
- Signs update on every edit with debouncing (300ms)
- Watches `.git/index` and `.git/HEAD` for external changes (e.g. `git checkout`, `git stash`, `git reset`)
- Navigate to next/previous hunk with wrapping
- Reset a single hunk, a visual selection of hunks, or the entire file

## Example config

```lua
vim.keymap.set("n", "]h", "<Plug>GitHunksNextHunk")
vim.keymap.set("n", "[h", "<Plug>GitHunksPrevHunk")

vim.keymap.set("n", "gh", "<Plug>GitHunksResetHunk")
vim.keymap.set("v", "gh", "<Plug>GitHunksResetHunk")
vim.keymap.set("n", "gH", "<Plug>GitHunksResetFile")
```

## Plug remaps

### `<Plug>GitHunksNextHunk`

Navigate to the next hunk. Wraps to the first hunk if none remain.

### `<Plug>GitHunksPrevHunk`

Navigate to the previous hunk. Wraps to the last hunk if none remain.

### `<Plug>GitHunksResetHunk`

- In normal mode: reset the hunk on the current line
- In visual mode: reset all hunks that overlap with the visual selection

### `<Plug>GitHunksResetFile`

Reset the entire file to the index version.

## Highlight groups

| Group            | Default link | Used for       |
| ---------------- | ------------ | -------------- |
| `DiffSignDelete` | `DiffDelete` | Deleted lines  |
| `DiffSignAdd`    | `DiffAdd`    | Added lines    |
| `DiffSignChange` | `DiffChange` | Modified lines |

## Autocommand events

### `User GitIndexChanged`

Fired when `.git/index` changes on disk (e.g. `git add`, `git checkout`, `git stash`, `git reset`).

### `User GitHeadChanged`

Fired when `.git/HEAD` changes on disk (e.g. `git checkout <branch>`, `git reset --hard`).
