# `git-diff.nvim`

Show git diff signs in the sign column and navigate, reset hunks.

## Features

- 1 source file (~400 LOC), no dependencies
- Async diff computation via coroutines (no UI freezing)
- Signs update on every edit with debouncing (300ms)
- Watches `.git/index` and `.git/HEAD` for external changes (e.g. `git checkout`, `git stash`, `git reset`)
- Navigate to next/previous hunk with wrapping
- Reset a single hunk, a visual selection of hunks, or the entire file

## Example config

```lua
vim.keymap.set("n", "]h", "<Plug>GitDiffNextHunk")
vim.keymap.set("n", "[h", "<Plug>GitDiffPrevHunk")
vim.keymap.set("n", "gh", "<Plug>GitDiffResetHunk")
vim.keymap.set("v", "gh", "<Plug>GitDiffResetHunk")
vim.keymap.set("n", "gH", "<Plug>GitDiffResetFile")
```

## Plug remaps

### `<Plug>GitDiffNextHunk`

Navigate to the next hunk. Wraps to the first hunk if none remain.

### `<Plug>GitDiffPrevHunk`

Navigate to the previous hunk. Wraps to the last hunk if none remain.

### `<Plug>GitDiffResetHunk`

- In normal mode: reset the hunk on the current line
- In visual mode: reset all hunks that overlap with the visual selection

### `<Plug>GitDiffResetFile`

Reset the entire file to the HEAD version.

## Highlight groups

| Group            | Default link | Used for       |
| ---------------- | ------------ | -------------- |
| `DiffSignDelete` | `DiffDelete` | Deleted lines  |
| `DiffSignAdd`    | `DiffAdd`    | Added lines    |
| `DiffSignChange` | `DiffChange` | Modified lines |

## Autocommand events

### `User GitIndexChanged`

Fired automatically when `.git/index` changes on disk (e.g. `git add`, `git checkout`, `git stash`, `git reset`)

### `User GitHeadChanged`

Fired automatically when `.git/HEAD` changes on disk (e.g. `git checkout <branch>`, `git reset --hard`)

## TODO:

- [ ] Test coverage
- [ ] Config (disabling, debounce time)
