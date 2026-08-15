# git-diff.nvim

A minimal Neovim plugin to view, navigate, and reset git hunks.

> **This project is small (~400 LOC in one file). When working on it, read the source at `lua/git-diff/init.lua` directly and include it in context — that's more reliable than any summary here.**

## Project overview

- **Source**: `lua/git-diff/init.lua` — all logic in one module
- **Plugin entry**: `plugin/git-diff.lua`
- **Docs**: `README.md`
- **Makefile**: `makefile`
- **Tests**: `tests/test_e2e.lua` — see the `testing` skill
- **Scripts**: `scripts/minimal_init.lua` — Neovim init for headless testing
- **No dependencies** beyond Neovim builtins (`vim.text.diff`, `vim.system`, `vim.uv`)
- **Targets nightly Neovim**. Uses modern APIs — when in doubt, check `:help` docs.
  - To look up a Neovim API: `nvim --headless -c "help vim.text.diff" -c ".,.+100w! /tmp/help.txt" -c "qa" 2>&1`
  - Adjust `100` as needed

### Async pattern

The plugin implements a lightweight coroutine-based async system to avoid blocking the UI during git operations:

- `async(fn)` — wraps a function to run in a coroutine via `coroutine.create` + `coroutine.resume`
- `await(promise)` — yields the current coroutine; `promise` is a `fun(resolve: fun())` called via `vim.schedule_wrap`
- `Promise` is just `fun(resolve: Resolve)` — call `resolve()` to resume the awaiting coroutine
