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

### Async pattern

The plugin implements a lightweight coroutine-based async system to avoid blocking the UI during git operations
