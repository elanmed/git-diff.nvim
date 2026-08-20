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

local function mock_read_index_files(files)
  child.lua([[
    local files = ...
    M.read_index_file = function(rel_filename)
      return function(resolve)
        resolve(files[rel_filename])
      end
    end
  ]], { files, })
end

local function mock_run_diff_cmd(fn_name, content)
  child.lua(string.format([[
    M.%s = function()
      return function(resolve) resolve(%q) end
    end
  ]], fn_name, content))
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

local expect_state = MiniTest.new_expectation(
  "state condition met",
  function(predicate, timeout)
    timeout = timeout or 1000
    return vim.wait(timeout, predicate)
  end,
  function(_, timeout)
    timeout = timeout or 1000
    return string.format("Expected state condition to be met after %d ms", timeout)
  end
)


local function set_worktree_buffer(rel_path, lines)
  child.bo.buftype = ""
  child.bo.readonly = false
  child.bo.modifiable = true
  child.api.nvim_buf_set_name(0, child.fn.getcwd() .. "/" .. rel_path)
  child.api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

local function set_named_buffer(rel_path, lines)
  child.bo.buftype = ""
  child.bo.readonly = false
  child.bo.modifiable = true
  child.api.nvim_buf_set_name(0, rel_path)
  child.api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

local function trigger_diff_update()
  child.cmd "doautocmd BufEnter"
end

local function get_diff_view_windows(filename)
  local new_win, old_win, files_win
  for _, win in ipairs(child.api.nvim_tabpage_list_wins(0)) do
    local bufnr = child.api.nvim_win_get_buf(win)
    local buftype = child.api.nvim_buf_get_option(bufnr, "buftype")
    local filetype = child.api.nvim_buf_get_option(bufnr, "filetype")
    local bufname = child.api.nvim_buf_get_name(bufnr)
    local basename = child.fn.fnamemodify(bufname, ":t")

    if filetype == "git-diff-view-file-list" then
      files_win = win
    elseif buftype == "" and basename == filename then
      new_win = win
    else
      old_win = win
    end
  end
  return new_win, old_win, files_win
end

local function get_win_lines(win_id)
  local bufnr = child.api.nvim_win_get_buf(win_id)
  return child.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function setup_diff_view_test(filename, worktree_lines, index_content)
  set_named_buffer(filename, worktree_lines)
  mock_read_index_files { [filename] = index_content, }
  trigger_diff_update()
  expect_hunks(child.api.nvim_get_current_buf())
  mock_run_diff_cmd("run_diff_cmd_worktree_index", filename .. "\n")
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
  child.lua [[vim.keymap.set("v", "<F1>", "<Plug>GitDiffResetHunk", { noremap = false, buffer = true, })]]
  child.type_keys "V"
  child.type_keys "j"
  child.type_keys "<F1>"

  expect_lines { "line1", "line2", "line3", "line4", "line5", }
end

T["reset file"] = new_set()

T["reset file"]["resets the entire file"] = function()
  mock_read_index_file [[line1
line2
line3
line4
line5
]]
  set_worktree_buffer("test.txt", { "line1 changed", "line2", "line3 changed", "line4", "line5 changed", })
  trigger_diff_update()

  local bufnr = child.api.nvim_get_current_buf()
  expect_hunks(bufnr)

  child.type_keys "<Plug>GitDiffResetFile"

  expect_lines { "line1", "line2", "line3", "line4", "line5", }
end

T["diff view"] = new_set()

T["diff view"]["opens a diff view tab"] = function()
  setup_diff_view_test("test.txt", { "line1 changed", "line2", "line3", }, [[line1
line2
line3
]])

  child.lua [[M.open_diff_view({ diff_type = "worktree-index" })]]

  expect_state(function()
    return #child.api.nvim_list_tabpages() == 2 and #child.api.nvim_tabpage_list_wins(0) == 3
  end)

  eq(#child.api.nvim_list_tabpages(), 2)
  eq(#child.api.nvim_tabpage_list_wins(0), 3)

  local new_win, old_win, files_win = get_diff_view_windows "test.txt"

  eq(get_win_lines(new_win), { "line1 changed", "line2", "line3", })
  eq(get_win_lines(old_win), { "line1", "line2", "line3", })
  eq(get_win_lines(files_win), { "test.txt", })
end

T["diff view"]["updates old/new content on file selection"] = function()
  set_named_buffer("a.txt", { "a1 changed", "a2", })
  child.cmd "badd b.txt"
  local b_bufnr = child.fn.bufnr "b.txt"
  child.api.nvim_buf_set_lines(b_bufnr, 0, -1, true, { "b1 changed", "b2", })

  mock_read_index_files {
    ["a.txt"] = "a1\na2\n",
    ["b.txt"] = "b1\nb2\n",
  }
  trigger_diff_update()
  expect_hunks(child.api.nvim_get_current_buf())
  mock_run_diff_cmd("run_diff_cmd_worktree_index", "a.txt\nb.txt\n")

  child.lua [[M.open_diff_view({ diff_type = "worktree-index" })]]

  expect_state(function()
    return #child.api.nvim_list_tabpages() == 2 and #child.api.nvim_tabpage_list_wins(0) == 3
  end)

  child.type_keys "j"

  expect_state(function()
    local new_win = get_diff_view_windows "b.txt"
    return new_win ~= nil
  end)

  local new_win, old_win = get_diff_view_windows "b.txt"
  eq(get_win_lines(new_win), { "b1 changed", "b2", })
  eq(get_win_lines(old_win), { "b1", "b2", })
end

T["diff view"]["toggles the diff view"] = function()
  setup_diff_view_test("test.txt", { "line1 changed", "line2", "line3", }, [[line1
line2
line3
]])

  child.lua [[M.toggle_diff_view({ diff_type = "worktree-index" })]]
  expect_state(function()
    return #child.api.nvim_list_tabpages() == 2
  end)
  eq(#child.api.nvim_list_tabpages(), 2)

  child.lua [[M.toggle_diff_view({ diff_type = "worktree-index" })]]
  expect_state(function()
    return #child.api.nvim_list_tabpages() == 1
  end)
  eq(#child.api.nvim_list_tabpages(), 1)
end

T["diff view"]["closes cleanly"] = new_set {
  parametrize = {
    { "new", },
    { "old", },
    { "files", },
  },
}

T["diff view"]["closes cleanly"]["closes when window closes"] = function(win_name)
  setup_diff_view_test("test.txt", { "line1 changed", "line2", "line3", }, [[line1
line2
line3
]])

  child.lua [[M.open_diff_view({ diff_type = "worktree-index" })]]
  expect_state(function()
    return #child.api.nvim_list_tabpages() == 2
  end)

  local new_win, old_win, files_win = get_diff_view_windows "test.txt"
  local win_to_close = ({ new = new_win, old = old_win, files = files_win, })[win_name]
  child.api.nvim_win_close(win_to_close, false)
  expect_state(function()
    return #child.api.nvim_list_tabpages() == 1
  end)
  eq(#child.api.nvim_list_tabpages(), 1)

  child.lua [[M.open_diff_view({ diff_type = "worktree-index" })]]
  expect_state(function()
    return #child.api.nvim_list_tabpages() == 2
  end)
  eq(#child.api.nvim_list_tabpages(), 2)
end

return T
