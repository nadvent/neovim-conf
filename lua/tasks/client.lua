local util = require 'core.util'

local M = {}

---@type { project_key: string|nil, project_name: string|nil, branch: string|nil, branch_issue_key: string|nil, timer_paused: boolean, active_issue: table|nil, today_active_seconds: integer, today_wall_seconds: integer, today_active_fmt: string, project_open_counts: table }
M.state = {
  project_key = nil,
  project_name = nil,
  branch = nil,
  branch_issue_key = nil,
  timer_paused = false,
  active_issue = nil,
  today_active_seconds = 0,
  today_wall_seconds = 0,
  today_active_fmt = '0s',
  project_open_counts = { total = 0, bugs = 0, in_progress = 0 },
}

local status_cbs = {}
local JSON_DECODE_OPTS = { luanil = { object = true, array = true } }
local state_epoch = 0
local cached_bin

--- Resolve the `tsk` executable path, preferring PATH with config fallback.
---@return string
function M.bin()
  if cached_bin then return cached_bin end
  if vim.fn.executable 'tsk' == 1 then
    local resolved = vim.fn.exepath 'tsk'
    cached_bin = (resolved ~= '' and resolved) or 'tsk'
  else
    cached_bin = vim.fn.stdpath 'config' .. '/tools/tsk/tsk'
  end
  return cached_bin
end

--- Format seconds into a compact duration string (mirrors CLI format_duration).
---@param seconds number|nil
---@return string
function M.format_duration(seconds)
  local sec = math.max(0, math.floor(tonumber(seconds) or 0))
  if sec < 60 then return string.format('%ds', sec) end
  local mins = math.floor(sec / 60)
  if mins < 60 then return string.format('%dm', mins) end
  local hrs = math.floor(mins / 60)
  local rem = mins % 60
  if rem == 0 then return string.format('%dh', hrs) end
  return string.format('%dh %02dm', hrs, rem)
end

local function update_state_if_status(decoded, min_epoch)
  if type(decoded) ~= 'table' or decoded.today_active_seconds == nil then return end
  if min_epoch and min_epoch < state_epoch then return end
  state_epoch = math.max(state_epoch + 1, (min_epoch or state_epoch) + 1)
  M.state = decoded
  for _, cb in ipairs(status_cbs) do
    pcall(cb, M.state)
  end
  pcall(vim.api.nvim_exec_autocmds, 'User', { pattern = 'TasksUpdated' })
end

--- Subscribe a callback for cached status updates.
---@param cb fun(state: table)
function M.on_update(cb) table.insert(status_cbs, cb) end

--- Run a `tsk` subcommand asynchronously and parse JSON if `--json` was requested.
---@param args string[]
---@param opts? { cwd?: string, stdin?: string, raw?: boolean, silent?: boolean }
---@param cb? fun(ok: boolean, result: any, err?: string)
function M.run(args, opts, cb)
  opts = opts or {}
  local cmd = { M.bin() }
  vim.list_extend(cmd, args)

  local sys_opts = {
    cwd = opts.cwd or vim.fn.getcwd(),
    text = true,
  }
  if opts.stdin ~= nil then sys_opts.stdin = opts.stdin end

  vim.system(cmd, sys_opts, function(res)
    vim.schedule(function()
      local stdout = res.stdout or ''
      local stderr = res.stderr or ''
      if res.code ~= 0 then
        local msg = stderr ~= '' and vim.trim(stderr) or vim.trim(stdout)
        if not opts.silent and msg ~= '' then vim.notify(msg, vim.log.levels.ERROR, { title = 'Tasks (tsk)' }) end
        if cb then cb(false, nil, msg) end
        return
      end

      if opts.raw then
        if cb then cb(true, stdout) end
        return
      end

      if stdout == '' then
        if cb then cb(true, nil) end
        return
      end

      local ok, decoded = pcall(vim.json.decode, stdout, JSON_DECODE_OPTS)
      if not ok then
        if cb then cb(true, stdout) end
        return
      end

      if type(decoded) == 'table' and decoded.error then
        if not opts.silent then vim.notify(decoded.error, vim.log.levels.ERROR, { title = 'Tasks (tsk)' }) end
        if cb then cb(false, decoded, decoded.error) end
        return
      end

      update_state_if_status(decoded, opts.expected_epoch)
      if cb then cb(true, decoded) end
    end)
  end)
end

--- Run a bounded synchronous `tsk` invocation (used on VimLeavePre or preview fills).
---@param args string[]
---@param opts? { cwd?: string, stdin?: string, timeout?: integer, raw?: boolean }
---@return boolean ok, any result
function M.run_sync(args, opts)
  opts = opts or {}
  local cmd = { M.bin() }
  vim.list_extend(cmd, args)
  local sys_opts = {
    cwd = opts.cwd or vim.fn.getcwd(),
    text = true,
  }
  if opts.stdin ~= nil then sys_opts.stdin = opts.stdin end

  local ok_sys, job = pcall(vim.system, cmd, sys_opts)
  if not ok_sys or not job then return false, nil end
  local res = job:wait(opts.timeout or 1500)
  if not res or res.code ~= 0 then return false, res and res.stderr or nil end
  if opts.raw then return true, res.stdout or '' end
  if not res.stdout or res.stdout == '' then return true, nil end
  local ok_dec, decoded = pcall(vim.json.decode, res.stdout, JSON_DECODE_OPTS)
  if not ok_dec then return true, res.stdout end
  update_state_if_status(decoded)
  return true, decoded
end

--- Spawn a fire-and-forget detached `tsk` subprocess so exit hooks never block Neovim.
---@param args string[]
---@param opts? { cwd?: string }
---@return boolean started
function M.run_detached(args, opts)
  opts = opts or {}
  local bin = M.bin()
  local spawn_args = {}
  vim.list_extend(spawn_args, args)

  local handle
  handle = vim.uv.spawn(bin, {
    args = spawn_args,
    cwd = opts.cwd or vim.fn.getcwd(),
    stdio = { nil, nil, nil },
    detached = true,
  }, function()
    if handle and not handle:is_closing() then pcall(handle.close, handle) end
  end)
  if not handle then return false end
  pcall(handle.unref, handle)
  return true
end

--- Asynchronously refresh cached task/timer status for `cwd`.
---@param cwd? string
---@param cb? fun(ok: boolean, state: table)
function M.refresh_status(cwd, cb)
  local target_cwd = cwd or vim.fn.getcwd()
  local dispatch_epoch = state_epoch
  M.run({ 'status', '--cwd', target_cwd, '--json' }, { cwd = target_cwd, silent = true, expected_epoch = dispatch_epoch }, function(ok, res)
    if cb then cb(ok, res or M.state) end
  end)
end

local type_icons = {
  bug = '',
  feature = '󰛨',
  epic = '󰚗',
  task = '',
  chore = '󰒓',
  subtask = '󰘍',
}

--- Return statusline segment info from the in-memory cache (0ms, no subprocess).
---@return { text: string, hl: string }|nil
function M.statusline_segment()
  local st = M.state
  local act = st.active_issue
  if type(act) == 'table' and act.key then
    local icon = st.timer_paused and '⏸' or (type_icons[act.issue_type] or '')
    local hl = st.timer_paused and 'StatusLineTaskPaused' or (act.issue_type == 'bug' and 'StatusLineTaskBug' or 'StatusLineTaskActive')
    -- Keep bugs clean of live ticking durations while preserving full metrics for analytics & docs
    if act.issue_type == 'bug' then
      return {
        text = string.format('%s %s', icon, act.key),
        hl = hl,
      }
    end
    local dur = act.active_fmt or M.format_duration(act.active_seconds)
    return {
      text = string.format('%s %s · %s', icon, act.key, dur),
      hl = hl,
    }
  end

  local counts = st.project_open_counts or {}
  local open_n = tonumber(counts.total) or 0
  if open_n > 0 and st.project_key then
    local bug_n = tonumber(counts.bugs) or 0
    local suffix = bug_n > 0 and string.format(' (%d)', bug_n) or ''
    return {
      text = string.format(' %s:%d%s', st.project_key, open_n, suffix),
      hl = 'StatusLineTaskIdle',
    }
  end
  return nil
end

--- Compute relative path of a buffer inside `root` or return normalized path.
---@param buf? integer
---@param root? string
---@return string|nil
function M.buffer_relpath(buf, root)
  local b = buf or 0
  if not vim.api.nvim_buf_is_valid(b) or vim.bo[b].buftype ~= '' then return nil end
  local name = vim.api.nvim_buf_get_name(b)
  if name == '' then return nil end
  local norm = vim.fs.normalize(name)
  if root and root ~= '' then
    local nr = vim.fs.normalize(root)
    if util.path_in_dir(norm, nr) then return norm:sub(#nr + 2) end
  end
  return norm
end

--- Detect enclosing Treesitter function/method/class/struct name around `lnum_0`.
---@param buf integer
---@param lnum_0 integer
---@return string|nil
function M.detect_ts_symbol(buf, lnum_0)
  local ok_node, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { lnum_0, 0 } })
  if not ok_node or not node then return nil end

  local cur = node
  while cur do
    local t = cur:type()
    if t:match 'function' or t:match 'method' or t:match 'class' or t:match 'struct' then
      for child in cur:iter_children() do
        local ct = child:type()
        if ct == 'identifier' or ct == 'name' or ct == 'field_identifier' or ct == 'property_identifier' then
          local txt = vim.treesitter.get_node_text(child, buf)
          if txt and txt ~= '' then return txt end
        end
      end
    end
    cur = cur:parent()
  end
  return nil
end

--- Capture current file/line/symbol context if cursor is inside a regular file buffer.
---@param buf? integer
---@param cwd? string
---@return { file: string|nil, line: integer|nil, symbol: string|nil }
function M.capture_cursor_location(buf, cwd)
  local b = buf or vim.api.nvim_get_current_buf()
  local rel = M.buffer_relpath(b, cwd or vim.fn.getcwd())
  if not rel then return {} end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  return {
    file = rel,
    line = lnum,
    symbol = M.detect_ts_symbol(b, math.max(0, lnum - 1)),
  }
end

--- Open anchored source file location for `issue` and jump to `source_line`.
---@param issue table
---@return boolean jumped
function M.open_issue_location(issue)
  if type(issue) ~= 'table' or not issue.source_file or issue.source_file == '' then return false end
  local candidates = {}
  local raw = issue.source_file
  if raw:match '^/' or raw:match '^~' then
    table.insert(candidates, vim.fs.normalize(vim.fn.expand(raw)))
  else
    if issue.project_root and issue.project_root ~= '' then
      table.insert(candidates, vim.fs.normalize(issue.project_root .. '/' .. raw))
    end
    table.insert(candidates, vim.fs.normalize(vim.fn.getcwd() .. '/' .. raw))
  end

  local target
  for _, path in ipairs(candidates) do
    if vim.fn.filereadable(path) == 1 then
      target = path
      break
    end
  end
  if not target then return false end

  vim.cmd('edit ' .. vim.fn.fnameescape(target))
  local line_no = math.max(1, tonumber(issue.source_line) or 1)
  local total = vim.api.nvim_buf_line_count(0)
  pcall(vim.api.nvim_win_set_cursor, 0, { math.min(line_no, total), 0 })
  vim.cmd 'normal! zz'
  return true
end

--- Wrapper over vim.ui.input ensuring Snacks.input always opens in Insert mode.
---@param opts table
---@param on_confirm fun(value?: string)
function M.prompt_input(opts, on_confirm)
  vim.schedule(function()
    vim.ui.input(opts, on_confirm)
    vim.schedule(function()
      if vim.bo.filetype == 'snacks_input' and vim.fn.mode() ~= 'i' then vim.cmd 'startinsert!' end
    end)
  end)
end

return M
