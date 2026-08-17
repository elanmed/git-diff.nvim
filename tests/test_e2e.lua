local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = new_set {
  hooks = {
    pre_case = function()
      child.restart { "-u", "scripts/minimal_init.lua", }
      child.lua [[M = require('git-diff')]]
      child.lua [[M.setup()]]
    end,
    post_once = child.stop,
  },
}

T["setup"] = new_set()

T["setup"]["creates global keymaps"] = function()
  -- TODO: verify <Plug>GitDiffNextHunk, <Plug>GitDiffPrevHunk, etc.
end

T["setup"]["creates global autocommands"] = function()
  -- TODO: verify GitDiff* autocommand groups exist.
end

T["hunk navigation"] = new_set()

T["hunk navigation"]["jumps to next hunk"] = function()
  -- TODO: stage a known file, modify it, then jump to next hunk.
end

T["hunk navigation"]["jumps to previous hunk"] = function()
  -- TODO: stage a known file, modify it, then jump to previous hunk.
end

T["hunk navigation"]["wraps to first hunk after last"] = function()
  -- TODO: test wrap-around from last hunk to first hunk.
end

T["hunk navigation"]["wraps to last hunk before first"] = function()
  -- TODO: test wrap-around from first hunk to last hunk.
end

T["hunk signs"] = new_set()

T["hunk signs"]["adds extmarks for added lines"] = function()
  -- TODO: verify DiffSignAdd extmarks on added lines.
end

T["hunk signs"]["adds extmarks for deleted lines"] = function()
  -- TODO: verify DiffSignDelete extmarks on deleted lines.
end

T["hunk signs"]["adds extmarks for changed lines"] = function()
  -- TODO: verify DiffSignChange extmarks on modified lines.
end

T["reset hunk"] = new_set()

T["reset hunk"]["resets a single-line hunk"] = function()
  -- TODO: modify a single line and reset it.
end

T["reset hunk"]["resets a multi-line hunk"] = function()
  -- TODO: modify multiple lines and reset them.
end

T["reset hunk"]["resets a deleted hunk"] = function()
  -- TODO: delete a line and reset it.
end

T["reset hunk"]["resets a visually selected range"] = function()
  -- TODO: modify several lines, select them in visual mode, and reset.
end

T["reset file"] = new_set()

T["reset file"]["resets the entire file"] = function()
  -- TODO: modify multiple hunks and reset the whole file.
end

T["diff view"] = new_set()

T["diff view"]["opens a diff view tab"] = function()
  -- TODO: call M.open_diff_view() and verify tab/windows/buffers.
end

T["diff view"]["lists changed files"] = function()
  -- TODO: verify the file list window contains expected file names.
end

T["diff view"]["shows old and new content"] = function()
  -- TODO: verify old/new window contents for a modified file.
end

T["diff view"]["updates old/new content on file selection"] = function()
  -- TODO: move cursor in file list and verify content updates.
end

T["diff view"]["toggles the diff view"] = function()
  -- TODO: call M.toggle_diff_view() to open and close the view.
end

T["diff view"]["closes cleanly"] = function()
  -- TODO: close the diff view and verify global state is cleared.
end

T["diff view"]["diff types"] = new_set {
  parametrize = {
    { "worktree-index" },
    { "worktree-head" },
    { "worktree-upstream" },
    { "index-head" },
    { "index-upstream" },
    { "head-upstream" },
  },
}

T["diff view"]["diff types"]["opens for diff type"] = function(diff_type)
  -- TODO: open diff view for `diff_type` and verify it loads the file list.
end

T["diff view"]["diff types"]["shows old location content"] = function(diff_type)
  -- TODO: open diff view for `diff_type` and verify old buffer content.
end

T["diff view"]["diff types"]["shows new location content"] = function(diff_type)
  -- TODO: open diff view for `diff_type` and verify new buffer content.
end


return T
