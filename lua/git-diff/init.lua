local M = {}

-- ====================
-- Async helpers
-- ====================

local function safe_resume(...)
  local ok, err = coroutine.resume(...)
  if not ok then error(err) end
end

--- @generic T
--- @param fn fun(resolve: Resolve<T>, ...: any): nil
--- @return fun(...: any): Promise<T>
local async = function(fn)
  return function(...)
    local args = { ..., }
    return function(resolve)
      local thread = coroutine.create(fn)
      safe_resume(thread, resolve, unpack(args))
    end
  end
end

--- @alias Resolve<T> fun(value?: T): nil
--- @alias Promise<T> fun(resolve: Resolve<T>): nil

--- @param fn fun(resolve: Resolve<any>, ...: any): nil
local unwaited_async = function(fn)
  return function(...)
    local promise = async(fn)(...)
    promise(function() end)
  end
end

--- @generic T
--- @param promise Promise<T>
--- @return T
local await = function(promise)
  local thread = coroutine.running()
  assert(thread ~= nil, "`await` can only be called in a coroutine")
  local scheduled_promise = vim.schedule_wrap(promise)
  local resolve = vim.schedule_wrap(function(...) safe_resume(thread, ...) end)
  scheduled_promise(resolve)
  return coroutine.yield()
end

-- ====================
-- Misc utils
-- ====================

--- @param input table
local tbl_reverse = function(input)
  local reversed = {}
  for index = #input, 1, -1 do
    table.insert(reversed, input[index])
  end
  return reversed
end

--- @generic T
--- @param val T | nil
--- @param fallback T
--- @return T
local if_nil = function(val, fallback)
  if val == nil then
    return fallback
  end
  return val
end

-- ====================
-- Diff
-- ====================

--- @class UnpackedHunk
--- @field start_old_1i number
--- @field start_old_0i number
--- @field count_old number
--- @field end_old_1i_excl number
--- @field end_old_1i_incl number
--- @field end_old_0i_excl number
--- @field end_old_0i_incl number
--- @field start_new_1i number
--- @field start_new_0i number
--- @field count_new number
--- @field end_new_1i_excl number
--- @field end_new_1i_incl number
--- @field end_new_0i_excl number
--- @field end_new_0i_incl number
--- @field is_deletion boolean
--- @field is_insertion boolean

--- @alias DiffHunk { [1]: integer, [2]: integer, [3]: integer, [4]: integer }
--- @param hunk DiffHunk
--- @return UnpackedHunk
M.unpack_hunk = function(hunk)
  local start_old_1i, count_old, start_new_1i, count_new = unpack(hunk)

  local start_old_0i = start_old_1i - 1
  local end_old_1i_excl = start_old_1i + count_old
  local end_old_1i_incl = end_old_1i_excl - 1
  local end_old_0i_excl = end_old_1i_excl - 1
  local end_old_0i_incl = end_old_1i_incl - 1

  local start_new_0i = start_new_1i - 1
  local end_new_1i_excl = start_new_1i + count_new
  local end_new_1i_incl = end_new_1i_excl - 1
  local end_new_0i_excl = end_new_1i_excl - 1
  local end_new_0i_incl = end_new_1i_incl - 1

  local is_deletion = count_new == 0
  local is_insertion = count_old == 0

  return {
    start_old_1i = start_old_1i,
    start_old_0i = start_old_0i,
    count_old = count_old,
    end_old_1i_excl = end_old_1i_excl,
    end_old_1i_incl = end_old_1i_incl,
    end_old_0i_excl = end_old_0i_excl,
    end_old_0i_incl = end_old_0i_incl,

    start_new_1i = start_new_1i,
    start_new_0i = start_new_0i,
    count_new = count_new,
    end_new_1i_excl = end_new_1i_excl,
    end_new_1i_incl = end_new_1i_incl,
    end_new_0i_excl = end_new_0i_excl,
    end_new_0i_incl = end_new_0i_incl,

    is_deletion = is_deletion,
    is_insertion = is_insertion,
  }
end

--- @alias FileLocation "worktree" | "index" | "head" | "upstream"
--- @alias DiffType "worktree-index" | "worktree-head" | "worktree-upstream" | "index-head" | "index-upstream" | "head-upstream"

--- @type fun(cmd: string[], opts: vim.SystemOpts?): Promise<string?>
local vim_system_stdout = async(
--- @param cmd string[]
--- @param opts vim.SystemOpts?
  function(resolve, cmd, opts)
    --- @type vim.SystemCompleted
    local out = await(function(inner_resolve) vim.system(cmd, opts, inner_resolve) end)
    if out.code ~= 0 then
      return resolve(nil)
    end

    return resolve(out.stdout)
  end
)

--- @class ResolveFileContentsParams
--- @field file_location FileLocation
--- @field rel_filename string
--- @field upstream_branch? string
--- @field file_bufnr? number

--- @type fun(opts: ResolveFileContentsParams): Promise<string?>
local resolve_file_contents = async(
--- @param opts ResolveFileContentsParams
  function(resolve, opts)
    local file_contents --- @type string?

    if opts.file_location == "worktree" then
      if opts.file_bufnr == nil then
        local file_lines = vim.fn.readfile(opts.rel_filename)
        file_contents = table.concat(file_lines, "\n")
      else
        local buf_lines = vim.api.nvim_buf_get_lines(opts.file_bufnr, 0, -1, false)
        file_contents = table.concat(buf_lines, "\n")
      end
    elseif opts.file_location == "index" then
      file_contents = await(vim_system_stdout { "git", "show", ":" .. opts.rel_filename, })
    elseif opts.file_location == "head" then
      file_contents = await(vim_system_stdout { "git", "show", "HEAD:" .. opts.rel_filename, })
    elseif opts.file_location == "upstream" then
      local upstream_branch = if_nil(opts.upstream_branch, "master")
      file_contents = await(vim_system_stdout { "git", "show", "origin/" .. upstream_branch .. ":" .. opts.rel_filename, })
    end

    if file_contents == nil then return resolve(nil) end
    resolve(file_contents:gsub("\n$", "") .. "\n")
  end
)


--- @class ResolveDiffTypeOpts
--- @field old_location FileLocation
--- @field new_location FileLocation

--- @param opts ResolveDiffTypeOpts
--- @return DiffType
local get_diff_type_from_file_locations = function(opts)
  return opts.new_location .. "-" .. opts.old_location
end

--- @param diff_type DiffType
--- @return FileLocation old_location
--- @return FileLocation new_location
local get_file_locations_from_diff_type = function(diff_type)
  return unpack(vim.split(diff_type, "-"))
end

--- @class ResolveDiffCmdOpts
--- @field diff_type DiffType
--- @field upstream_branch? string

--- @param opts ResolveDiffCmdOpts
local resolve_diff_cmd = function(opts)
  local upstream_branch = if_nil(opts.upstream_branch, "master")

  if opts.diff_type == "worktree-index" then
    return { "git", "diff", "--name-only", }
  elseif opts.diff_type == "worktree-head" then
    return { "git", "diff", "--name-only", "HEAD", }
  elseif opts.diff_type == "worktree-upstream" then
    return { "git", "diff", "--name-only", "origin/" .. upstream_branch, }
  elseif opts.diff_type == "index-head" then
    return { "git", "diff", "--name-only", "--cached", }
  elseif opts.diff_type == "index-upstream" then
    return { "git", "diff", "--name-only", "--cached", "origin/" .. upstream_branch, }
  elseif opts.diff_type == "head-upstream" then
    return { "git", "diff", "--name-only", "HEAD", "origin/" .. upstream_branch, }
  end
end

--- @class GenerateDiffParams
--- @field old_file_location FileLocation
--- @field new_file_location FileLocation
--- @field rel_filename string
--- @field upstream_branch? string
--- @field file_bufnr? number

--- @type fun(opts: GenerateDiffParams): Promise<DiffHunk[]?>
local generate_diff = async(
--- @param opts GenerateDiffParams
  function(resolve, opts)
    local old_str = await(resolve_file_contents {
      file_location = opts.old_file_location,
      rel_filename = opts.rel_filename,
      upstream_branch = opts.upstream_branch,
      file_bufnr = opts.file_bufnr,
    })
    if old_str == nil then return resolve(nil) end
    local new_str = await(resolve_file_contents {
      file_location = opts.new_file_location,
      rel_filename = opts.rel_filename,
      upstream_branch = opts.upstream_branch,
      file_bufnr = opts.file_bufnr,
    })
    if new_str == nil then return resolve(nil) end

    resolve(vim.text.diff(old_str, new_str, { result_type = "indices", }))
  end
)

--- @class DiffState
--- @field indices DiffHunk[]
--- @field index_lines string[]

--- @type table<number, DiffState>
local buffer_state = {}

local ns_id = vim.api.nvim_create_namespace "GitDiff"

--- @type fun(bufnr: number): Promise
local update_state_for_buf = async(
--- @param bufnr number
  function(resolve, bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return resolve() end
    local bufname = vim.fs.relpath(vim.fn.getcwd(), vim.api.nvim_buf_get_name(bufnr))
    if bufname == nil then return resolve() end

    local indices = await(generate_diff { rel_filename = bufname, old_file_location = "index", new_file_location = "worktree", file_bufnr = bufnr, })
    if indices == nil then return resolve() end

    local index_str = await(resolve_file_contents { file_location = "index", rel_filename = bufname, })
    if index_str == nil then return resolve() end
    local index_lines = vim.split(index_str, "\n", { trimempty = true, })

    buffer_state[bufnr] = {
      indices = indices,
      index_lines = index_lines,
    }
    resolve()
  end
)

local update_signs = vim.schedule_wrap(function()
  local curr_bufnr = vim.api.nvim_get_current_buf()
  local state = buffer_state[curr_bufnr]

  if state == nil then
    return
  end

  local rows_to_hl = {}
  for _, raw_hunk in ipairs(state.indices) do
    local hunk = M.unpack_hunk(raw_hunk)

    local hunk_hl_group = (function()
      if hunk.is_deletion then return "DiffSignDelete" end
      if hunk.is_insertion then return "DiffSignAdd" end
      return "DiffSignChange"
    end)()

    for row_1i = hunk.start_new_1i, math.max(hunk.end_new_1i_incl, hunk.start_new_1i) do
      local row_0i = row_1i - 1
      if row_0i >= 0 then
        table.insert(rows_to_hl, { row_0i = row_0i, hl = hunk_hl_group, })
      end
    end
  end

  vim.api.nvim_buf_clear_namespace(curr_bufnr, ns_id, 0, -1)
  for _, row_to_hl in ipairs(rows_to_hl) do
    vim.api.nvim_buf_set_extmark(curr_bufnr, ns_id, row_to_hl.row_0i, 0, {
      number_hl_group = row_to_hl.hl,
    })
  end
end)


--- @param direction 'next' | 'prev'
local function navigate_hunk(direction)
  local curr_bufnr = vim.api.nvim_get_current_buf()
  local state = buffer_state[curr_bufnr]

  if state == nil then
    return vim.notify("Missing diff state for this buffer", vim.log.levels.ERROR)
  end

  local indices = (function()
    if direction == "next" then return state.indices end
    return tbl_reverse(state.indices)
  end)()

  if #indices == 0 then
    return vim.notify("No hunks", vim.log.levels.ERROR)
  end

  local row_1i = vim.api.nvim_win_get_cursor(0)[1]
  local next_hunk_row_1i = nil

  for _, raw_hunk in ipairs(indices) do
    local hunk = M.unpack_hunk(raw_hunk)
    if direction == "next" then
      if hunk.start_new_1i > row_1i then
        next_hunk_row_1i = hunk.start_new_1i
        break
      end
    else
      if hunk.start_new_1i < row_1i then
        next_hunk_row_1i = hunk.start_new_1i
        break
      end
    end
  end

  if next_hunk_row_1i == nil then
    if direction == "next" then
      local hunk = M.unpack_hunk(indices[1])
      vim.api.nvim_win_set_cursor(0, { hunk.start_new_1i, 0, })
      return vim.notify("Wrapping to the first hunk", vim.log.levels.INFO)
    else
      local hunk = M.unpack_hunk(indices[#indices])
      vim.api.nvim_win_set_cursor(0, { hunk.start_new_1i, 0, })
      return vim.notify("Wrapping to the last hunk", vim.log.levels.INFO)
    end
  end

  vim.api.nvim_win_set_cursor(0, { next_hunk_row_1i, 0, })
end

--- @class ResetHunkOpts
--- @field state DiffState
--- @field start_line_1i number
--- @field end_line_1i_incl number
--- @field curr_bufnr number
--- @param opts ResetHunkOpts
local function reset_hunk(opts)
  local matching_hunks = {}
  for _, raw_hunk in ipairs(opts.state.indices) do
    local hunk = M.unpack_hunk(raw_hunk)

    local hunk_overlaps_range = false
    if hunk.is_deletion then
      hunk_overlaps_range =
          hunk.start_new_1i >= opts.start_line_1i and
          hunk.start_new_1i <= opts.end_line_1i_incl
    else
      hunk_overlaps_range =
          hunk.end_new_1i_incl >= opts.start_line_1i and
          hunk.start_new_1i <= opts.end_line_1i_incl
    end

    if hunk_overlaps_range then
      table.insert(matching_hunks, hunk)
    end
  end

  for _, hunk in ipairs(tbl_reverse(matching_hunks)) do
    local head_chunk = vim.list_slice(opts.state.index_lines, hunk.start_old_1i, hunk.end_old_1i_incl)

    if hunk.is_deletion then
      local insert_after_0i = hunk.start_new_0i + 1
      vim.api.nvim_buf_set_lines(opts.curr_bufnr, insert_after_0i, insert_after_0i, true, head_chunk)
    else
      vim.api.nvim_buf_set_lines(opts.curr_bufnr, hunk.start_new_0i, hunk.end_new_0i_excl, true, head_chunk)
    end
  end
end

local setup_global_autocmds = function()
  local timer = nil
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", }, {
    group = vim.api.nvim_create_augroup("GitDiffTextEvents", { clear = true, }),
    callback = function(event)
      if timer then vim.fn.timer_stop(timer) end

      timer = vim.fn.timer_start(300, unwaited_async(function()
        if event.buf ~= vim.api.nvim_get_current_buf() then return end
        await(update_state_for_buf(event.buf))
        update_signs()
      end))
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter", "BufWritePost", }, {
    group = vim.api.nvim_create_augroup("GitDiffBufEvents", { clear = true, }),
    callback = unwaited_async(function(_, event)
      if event.buf ~= vim.api.nvim_get_current_buf() then return end
      await(update_state_for_buf(event.buf))
      update_signs()
    end),
  })

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("GitDiffIndexEvents", { clear = true, }),
    pattern = { "GitIndexChanged", },
    callback = unwaited_async(function()
      local bufs = {}
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[bufnr].buftype == "" and vim.api.nvim_buf_is_loaded(bufnr) then
          table.insert(bufs, bufnr)
        end
      end

      for _, bufnr in ipairs(bufs) do
        await(update_state_for_buf(bufnr))
      end
      update_signs()
    end),
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = vim.api.nvim_create_augroup("GitDiffCleanup", { clear = true, }),
    callback = function(event)
      buffer_state[event.buf] = nil
    end,
  })
end

--- @type fun():nil
local setup_file_watcher = unwaited_async(function()
  local git_dir = await(vim_system_stdout { "git", "rev-parse", "--absolute-git-dir", })
  if git_dir == nil then return end
  git_dir = vim.trim(git_dir)

  local index_watch = vim.uv.new_fs_event()
  if index_watch == nil then return end

  index_watch:start(git_dir, {}, function(_, filename)
    vim.schedule(function()
      if filename == "index" then
        vim.api.nvim_exec_autocmds("User", { pattern = "GitIndexChanged", })
      elseif filename == "HEAD" then
        vim.api.nvim_exec_autocmds("User", { pattern = "GitHeadChanged", })
      end
    end)
  end)
end)

local setup_global_keymaps = function()
  vim.keymap.set("n", "<Plug>GitDiffNextHunk", function() navigate_hunk "next" end,
    { desc = "Navigate to the next hunk", })
  vim.keymap.set("n", "<Plug>GitDiffPrevHunk", function() navigate_hunk "prev" end,
    { desc = "Navigate to the prev hunk", })

  vim.keymap.set("n", "<Plug>GitDiffResetHunk", function()
    local curr_bufnr = vim.api.nvim_get_current_buf()
    local state = buffer_state[curr_bufnr]
    if state == nil then
      return vim.notify("Missing diff state for this buffer", vim.log.levels.ERROR)
    end

    local row_1i = vim.api.nvim_win_get_cursor(0)[1]
    reset_hunk { state = state, curr_bufnr = curr_bufnr, start_line_1i = row_1i, end_line_1i_incl = row_1i, }
  end, { desc = "Reset the hunk on the current line", })

  vim.keymap.set("v", "<Plug>GitDiffResetHunk", function()
    local curr_bufnr = vim.api.nvim_get_current_buf()
    local state = buffer_state[curr_bufnr]
    if state == nil then
      return vim.notify("Missing diff state for this buffer", vim.log.levels.ERROR)
    end

    local start_visual_1i = vim.fn.line "v"
    local end_visual_1i = vim.fn.line "."
    local start_selection_1i = math.min(start_visual_1i, end_visual_1i)
    local end_selection_1i = math.max(start_visual_1i, end_visual_1i)

    reset_hunk { state = state, curr_bufnr = curr_bufnr, start_line_1i = start_selection_1i, end_line_1i_incl = end_selection_1i, }
  end, { desc = "Reset the visually selected hunk", })

  vim.keymap.set("n", "<Plug>GitDiffResetFile", function()
    local curr_bufnr = vim.api.nvim_get_current_buf()
    local state = buffer_state[curr_bufnr]
    if state == nil then
      return vim.notify("Missing diff state for this buffer", vim.log.levels.ERROR)
    end

    reset_hunk {
      state = state,
      curr_bufnr = curr_bufnr,
      start_line_1i = 1,
      end_line_1i_incl = vim.api.nvim_buf_line_count(curr_bufnr),
    }
  end, { desc = "Reset the entire file", })
end


local state = {
  new_winnr = nil,
  new_bufnr = nil,
  old_winnr = nil,
  old_bufnr = nil,
  file_list_winnr = nil,
  file_list_bufnr = nil,
}

--- @class ShouldUseRealFilenameBufnrOpts
--- @field diff_type DiffType
--- @field rel_filename string

--- @param opts ShouldUseRealFilenameBufnrOpts
local function should_use_real_filename_bufnr(opts)
  local filename_bufnr = vim.fn.bufnr(opts.rel_filename)
  if filename_bufnr == -1 then return false end

  return vim.list_contains({ "worktree-index", "worktree-head", "worktree-upstream", }, opts.diff_type)
end

--- @class UpdateDiffViewParams
--- @field diff_type DiffType
--- @field upstream_branch? string
--- @field rel_filename string

--- @type fun(opts: UpdateDiffViewParams): nil
local update_diff_view = unwaited_async(
--- @param opts UpdateDiffViewParams
  function(_, opts)
    local new_file_location, old_file_location = get_file_locations_from_diff_type(opts.diff_type)

    local filename_bufnr = vim.fn.bufnr(opts.rel_filename)
    local use_real_filename_bufnr = should_use_real_filename_bufnr {
      diff_type = opts.diff_type,
      rel_filename = opts.rel_filename,
    }

    if use_real_filename_bufnr then
      vim.api.nvim_win_set_buf(state.new_winnr, filename_bufnr)
    else
      vim.api.nvim_win_set_buf(state.new_winnr, state.new_bufnr)
      local new_str = await(resolve_file_contents {
        file_location = new_file_location,
        rel_filename = opts.rel_filename,
        upstream_branch = opts.upstream_branch,
      })
      new_str = if_nil(new_str, "Could not open " .. opts.rel_filename .. " from " .. new_file_location)
      local new_lines = vim.split(new_str, "\n", { trimempty = true, })
      vim.api.nvim_buf_set_lines(state.new_bufnr, 0, -1, false, new_lines)
    end

    local old_str = await(resolve_file_contents {
      file_location = old_file_location,
      rel_filename = opts.rel_filename,
      upstream_branch = opts.upstream_branch,
    })
    old_str = if_nil(old_str, "Could not open " .. opts.rel_filename .. " from " .. old_file_location)
    local old_lines = vim.split(old_str, "\n", { trimempty = true, })
    vim.api.nvim_buf_set_lines(state.old_bufnr, 0, -1, false, old_lines)

    vim.cmd.diffupdate()
  end
)

--- @class OpenDiffViewParams
--- @field diff_type DiffType
--- @field upstream_branch? string

--- @type fun(opts: OpenDiffViewParams): nil
local open_diff_view = unwaited_async(
--- @param opts OpenDiffViewParams
  function(_, opts)
    vim.cmd.tabnew()

    state.upstream_branch = opts.upstream_branch
    state.new_bufnr = vim.api.nvim_create_buf(false, true)
    state.new_winnr = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(state.new_winnr, state.new_bufnr)
    vim.wo[state.new_winnr].winbar = "New"

    state.old_bufnr = vim.api.nvim_create_buf(false, true)
    state.old_winnr = vim.api.nvim_open_win(state.old_bufnr, true, {
      split = "left",
      win = state.new_winnr,
    })
    vim.wo[state.old_winnr].winbar = "Old"

    local diff_cmd = resolve_diff_cmd {
      diff_type = opts.diff_type,
      upstream_branch = opts.upstream_branch,
    }
    local file_list_str = await(vim_system_stdout(diff_cmd))
    file_list_str = if_nil(file_list_str, "")
    local file_list_lines = vim.split(file_list_str, "\n", { trimempty = true, })

    state.file_list_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(state.file_list_bufnr, 0, -1, false, file_list_lines)
    vim.cmd "botright 10split"
    state.file_list_winnr = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(state.file_list_winnr, state.file_list_bufnr)
    vim.wo[state.file_list_winnr].winbar = "Files"
    vim.bo[state.file_list_bufnr].modifiable = false
    vim.bo[state.file_list_bufnr].filetype = "git-diff-view-file-list"

    vim.api.nvim_win_call(state.old_winnr, vim.cmd.diffthis)
    vim.api.nvim_win_call(state.new_winnr, vim.cmd.diffthis)

    vim.api.nvim_create_autocmd({ "CursorMoved", }, {
      group = vim.api.nvim_create_augroup("GitDiffViewFileListCursorMove", { clear = true, }),
      buf = state.file_list_bufnr,
      callback = function()
        local rel_filename = vim.api.nvim_win_call(state.file_list_winnr, vim.api.nvim_get_current_line)
        if rel_filename == nil or rel_filename == "" then return end
        update_diff_view { diff_type = opts.diff_type, rel_filename = rel_filename, upstream_branch = state.upstream_branch, }
      end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
      group = vim.api.nvim_create_augroup("GitDiffViewFileListWinClosed", { clear = true, }),
      pattern = { tostring(state.new_winnr), tostring(state.old_winnr), tostring(state.file_list_winnr), },
      callback = function()
        if vim.api.nvim_win_is_valid(state.new_winnr) then vim.api.nvim_win_close(state.new_winnr, false) end
        if vim.api.nvim_win_is_valid(state.old_winnr) then vim.api.nvim_win_close(state.old_winnr, false) end
        if vim.api.nvim_win_is_valid(state.file_list_winnr) then vim.api.nvim_win_close(state.file_list_winnr, false) end
      end,
    })

    vim.keymap.set("n", "<Plug>GitDiffViewScrollDown", function()
      vim.api.nvim_win_call(state.old_winnr, function()
        vim.cmd [[execute "normal! \<C-d>"]]
      end)
    end, { desc = "Scroll down in the diff view", })

    vim.keymap.set("n", "<Plug>GitDiffViewScrollUp", function()
      vim.api.nvim_win_call(state.old_winnr, function()
        vim.cmd [[execute "normal! \<C-u>"]]
      end)
    end, { desc = "Scroll up in the diff view", })
  end
)

local demo = function()
  local bufnr = vim.api.nvim_get_current_buf()

  local cwd = vim.uv.cwd()
  assert(cwd ~= nil)
  local curr_bufname = vim.fs.relpath(cwd, vim.api.nvim_buf_get_name(bufnr))
  assert(curr_bufname ~= nil)

  open_diff_view { upstream_branch = "master", diff_type = "index-upstream", }
end
vim.keymap.set("n", "<leader>d", demo)

M.setup = function()
  setup_global_autocmds()
  setup_file_watcher()
  setup_global_keymaps()
end

return M
