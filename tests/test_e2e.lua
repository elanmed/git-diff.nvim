local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local expect_hunks = MiniTest.new_expectation(
  "buffer has diff hunks",
  function(bufnr, timeout)
    timeout = timeout or 1000
    local ns_id = child.api.nvim_create_namespace "GitDiff"
    return child.lua_get(string.format([[
      vim.wait(%d, function()
        return #vim.api.nvim_buf_get_extmarks(%d, %d, 0, -1, {}) > 0
      end)
    ]], timeout, bufnr, ns_id))
  end,
  function(bufnr, timeout)
    timeout = timeout or 1000
    local ns_id = child.api.nvim_create_namespace "GitDiff"
    local count = #child.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})
    return string.format(
      "Expected buffer %s to have GitDiff extmarks after %d ms, found %d",
      tostring(bufnr),
      timeout,
      count
    )
  end
)

local expect_cursor = MiniTest.new_expectation(
  "cursor at line",
  function(line, col)
    local cursor = child.api.nvim_win_get_cursor(0)
    if col == nil then
      return cursor[1] == line
    end
    return cursor[1] == line and cursor[2] == col
  end,
  function(line, col)
    local cursor = child.api.nvim_win_get_cursor(0)
    if col == nil then
      return string.format("Expected cursor at line %d, actual line %d", line, cursor[1])
    end
    return string.format(
      "Expected cursor at line %d col %d, actual line %d col %d",
      line,
      col,
      cursor[1],
      cursor[2]
    )
  end
)


local function mock_read_index_file(content)
  child.lua(string.format([[
    M.read_index_file = function()
      return function(resolve) resolve(%q) end
    end
  ]], content))
end

local expect_sign = MiniTest.new_expectation(
  "line has expected sign",
  function(bufnr, line_1i, hl_group)
    local ns_id = child.api.nvim_create_namespace "GitDiff"
    local marks = child.api.nvim_buf_get_extmarks(
      bufnr,
      ns_id,
      { line_1i - 1, 0, },
      { line_1i - 1, -1, },
      { details = true, }
    )
    if #marks == 0 then return false end
    return marks[1][4].number_hl_group == hl_group
  end,
  function(bufnr, line_1i, hl_group)
    local ns_id = child.api.nvim_create_namespace "GitDiff"
    local marks = child.api.nvim_buf_get_extmarks(
      bufnr,
      ns_id,
      { line_1i - 1, 0, },
      { line_1i - 1, -1, },
      { details = true, }
    )
    if #marks == 0 then
      return string.format("Expected %s sign on line %d, found no extmarks", hl_group, line_1i)
    end
    return string.format(
      "Expected %s sign on line %d, found %s",
      hl_group,
      line_1i,
      marks[1][4].number_hl_group or "none"
    )
  end
)

local expect_lines = MiniTest.new_expectation(
  "buffer lines",
  function(expected_lines)
    return vim.deep_equal(child.api.nvim_buf_get_lines(0, 0, -1, false), expected_lines)
  end,
  function(expected_lines)
    local actual_lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    return string.format(
      "Expected lines:\n%s\nActual lines:\n%s",
      vim.inspect(expected_lines),
      vim.inspect(actual_lines)
    )
  end
)


local function set_worktree_buffer(rel_path, lines)
  child.bo.buftype = ""
  child.bo.readonly = false
  child.bo.modifiable = true
  child.api.nvim_buf_set_name(0, child.fn.getcwd() .. "/" .. rel_path)
  child.api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

local function trigger_diff_update()
  child.cmd "doautocmd BufEnter"
end


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
  mock_read_index_file [[line1
line2
line3
line4
line5
]]
  set_worktree_buffer("test.txt", { "line1", "line2 changed", "line3", "line4 changed", "line5", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)

  child.api.nvim_win_set_cursor(0, { 1, 0, })
  child.type_keys "<Plug>GitDiffNextHunk"

  expect_cursor(2)
end

T["hunk navigation"]["jumps to previous hunk"] = function()
  mock_read_index_file [[line1
line2
line3
line4
line5
]]
  set_worktree_buffer("test.txt", { "line1", "line2 changed", "line3", "line4 changed", "line5", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)

  child.api.nvim_win_set_cursor(0, { 4, 0, })
  child.type_keys "<Plug>GitDiffPrevHunk"

  expect_cursor(2)
end

T["hunk navigation"]["wraps to first hunk after last"] = function()
  mock_read_index_file [[line1
line2
line3
line4
line5
]]
  set_worktree_buffer("test.txt", { "line1", "line2 changed", "line3", "line4 changed", "line5", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)

  child.api.nvim_win_set_cursor(0, { 5, 0, })
  child.type_keys "<Plug>GitDiffNextHunk"

  expect_cursor(2)
end

T["hunk navigation"]["wraps to last hunk before first"] = function()
  mock_read_index_file [[line1
line2
line3
line4
line5
]]
  set_worktree_buffer("test.txt", { "line1", "line2 changed", "line3", "line4 changed", "line5", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)

  child.api.nvim_win_set_cursor(0, { 1, 0, })
  child.type_keys "<Plug>GitDiffPrevHunk"

  expect_cursor(4)
end

T["hunk signs"] = new_set()

T["hunk signs"]["adds extmarks for added lines"] = function()
  mock_read_index_file [[line1
line2
line3
]]
  set_worktree_buffer("test.txt", { "line1", "line2", "line3", "line4", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)
  expect_sign(bufnr, 4, "DiffSignAdd")
end

T["hunk signs"]["adds extmarks for deleted lines"] = function()
  mock_read_index_file [[line1
line2
line3
line4
]]
  set_worktree_buffer("test.txt", { "line1", "line2", "line4", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)
  expect_sign(bufnr, 2, "DiffSignDelete")
end

T["hunk signs"]["adds extmarks for changed lines"] = function()
  mock_read_index_file [[line1
line2
line3
]]
  set_worktree_buffer("test.txt", { "line1", "line2 changed", "line3", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)
  expect_sign(bufnr, 2, "DiffSignChange")
end

T["reset hunk"] = new_set()

T["reset hunk"]["resets a single-line hunk"] = function()
  mock_read_index_file [[line1
line2
line3
line4
line5
]]
  set_worktree_buffer("test.txt", { "line1", "line2 changed", "line3", "line4", "line5", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)

  child.api.nvim_win_set_cursor(0, { 2, 0, })
  child.type_keys "<Plug>GitDiffResetHunk"

  expect_lines { "line1", "line2", "line3", "line4", "line5", }
end

T["reset hunk"]["resets a multi-line hunk"] = function()
  mock_read_index_file [[line1
line2
line3
line4
line5
]]
  set_worktree_buffer("test.txt", { "line1", "line2 changed", "line3 changed", "line4", "line5", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)

  child.api.nvim_win_set_cursor(0, { 2, 0, })
  child.type_keys "<Plug>GitDiffResetHunk"

  expect_lines { "line1", "line2", "line3", "line4", "line5", }
end

T["reset hunk"]["resets a deleted hunk"] = function()
  mock_read_index_file [[line1
line2
line3
line4
line5
]]
  set_worktree_buffer("test.txt", { "line1", "line3", "line4", "line5", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)

  child.api.nvim_win_set_cursor(0, { 1, 0, })
  child.type_keys "<Plug>GitDiffResetHunk"

  expect_lines { "line1", "line2", "line3", "line4", "line5", }
end

T["reset hunk"]["does nothing when cursor is not on a hunk"] = function()
  mock_read_index_file [[line1
line2
line3
line4
line5
]]
  set_worktree_buffer("test.txt", { "line1", "line2 changed", "line3", "line4", "line5", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)

  child.api.nvim_win_set_cursor(0, { 4, 0, })
  child.type_keys "<Plug>GitDiffResetHunk"

  expect_lines { "line1", "line2 changed", "line3", "line4", "line5", }
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
    { "worktree-index", },
    { "worktree-head", },
    { "worktree-upstream", },
    { "index-head", },
    { "index-upstream", },
    { "head-upstream", },
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
