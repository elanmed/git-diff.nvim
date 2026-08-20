# `git-diff.nvim`

A minimal plugin to view, navigate, and reset git hunks. Also includes a diff view for comparing any two git file locations.

## Features

- 1 source file (~730 LOC), no dependencies
- Async diff computation via coroutines (no UI freezing)
- Signs update on every edit with debouncing (300ms)
- Watches `.git/index` and `.git/HEAD` for external changes (e.g. `git checkout`, `git stash`, `git reset`)
- Navigate to next/previous hunk with wrapping
- Reset a single hunk, a visual selection of hunks, or the entire file
- Diff view: compare worktree, index, HEAD, upstream, and merge-base versions in a side-by-side split with file list

## Example config

```lua
vim.keymap.set("n", "]h", "<Plug>GitDiffNextHunk")
vim.keymap.set("n", "[h", "<Plug>GitDiffPrevHunk")

vim.keymap.set("n", "gh", "<Plug>GitDiffResetHunk")
vim.keymap.set("v", "gh", "<Plug>GitDiffResetHunk")
vim.keymap.set("n", "gH", "<Plug>GitDiffResetFile")

vim.keymap.set("n", "<leader>gd", function()
  require("git-diff").toggle_diff_view { diff_type = "worktree-index" }
end)
vim.keymap.set("n", "<leader>gD", function()
  require("git-diff").toggle_diff_view { diff_type = "worktree-head" }
end)
vim.keymap.set("n", "<leader>gm", function()
  require("git-diff").toggle_diff_view { diff_type = "head-mergebase" }
end)
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

Reset the entire file to the index version.

### `<Plug>GitDiffViewScrollDown`

Scroll down in the diff view (both splits simultaneously).

### `<Plug>GitDiffViewScrollUp`

Scroll up in the diff view (both splits simultaneously).

### `<Plug>GitDiffViewRefresh`

Refresh the list of files with diffs.

## API

### `require("git-diff").open_diff_view(opts)`

Opens a new tab with a 3-pane diff view:

- **Old** (left): the old file version
- **New** (right): the new file version
- **Files** (bottom): list of changed files

`opts`:

- `diff_type` (`string`): one of `"worktree-index"`, `"worktree-head"`, `"worktree-upstream"`, `"worktree-mergebase"`, `"index-head"`, `"index-upstream"`, `"index-mergebase"`, `"head-upstream"`, `"head-mergebase"`
- `upstream_branch` (`string?`): upstream branch name (default: `"master"`)

If the diff view tab already exists, switches to it instead of creating a new one.

### `require("git-diff").toggle_diff_view(opts)`

Toggles the diff view: opens it if not open, closes it if already open.

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

### `User GitDiffViewOpen`

Fired after the diff view opens. `data` contains `old_winnr`, `new_winnr`, `file_list_winnr`, `old_bufnr`, `new_bufnr`, `file_list_bufnr`.

## Filetype

The file list buffer in the diff view uses `git-diff-view-file-list` filetype for custom highlighting or keymaps.
