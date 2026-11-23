local util = require 'core.util'
local client = require 'tasks.client'

local M = {}

local IDLE_CUTOFF_MS = 300000 -- 5 minutes
local FLUSH_INTERVAL_MS = 30000 -- 30 seconds

local state = {
  started = false,
  instance_id = string.format('nvim-%d-%s', vim.fn.getpid(), tostring(vim.uv.hrtime())),
  timer = nil,
  focused = true,
  last_input_ms = 0,
  last_tick_ms = 0,
  flushing = false,
  has_flushed = false,
}

local function mark_activity() state.last_input_ms = vim.uv.now() end

local function current_file_path()
  local buf = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= '' then return nil end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then return nil end
  return vim.fs.normalize(name)
end

local function build_heartbeat_payload(now, wall_sec)
  local clamped_wall = math.max(0, math.min(wall_sec, 180))
  local is_active = state.focused and ((now - state.last_input_ms) <= IDLE_CUTOFF_MS)
  local active_sec = (clamped_wall > 0 and is_active) and clamped_wall or 0
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  local payload = vim.json.encode {
    instance_id = state.instance_id,
    cwd = cwd,
    file = current_file_path(),
    active_delta_sec = active_sec,
    wall_delta_sec = clamped_wall,
    is_active = is_active,
  }
  return cwd, payload
end

--- Flush buffered activity delta to `tsk heartbeat`.
---@param sync? boolean
function M.flush(sync)
  if not state.started then return end
  if not sync and state.flushing then return end

  local now = vim.uv.now()
  local wall_sec = math.floor((now - state.last_tick_ms) / 1000)
  if wall_sec <= 0 then return end
  state.last_tick_ms = now
  state.has_flushed = true

  local cwd, payload = build_heartbeat_payload(now, wall_sec)
  local args = { 'heartbeat', '--json', '--payload', payload }
  if sync then
    client.run_sync(args, { cwd = cwd, timeout = 400 })
  else
    state.flushing = true
    client.run(args, { cwd = cwd, silent = true }, function() state.flushing = false end)
  end
end

--- Start the deferred activity & branch-context heartbeat tracker.
function M.start()
  if state.started then return end
  state.started = true

  local now = vim.uv.now()
  state.last_input_ms = now
  state.last_tick_ms = now

  local aug = util.augroup 'tasks_tracker'

  vim.api.nvim_create_autocmd({
    'CursorMoved',
    'CursorMovedI',
    'TextChanged',
    'TextChangedI',
    'InsertEnter',
    'CmdlineEnter',
  }, {
    group = aug,
    callback = mark_activity,
  })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = aug,
    callback = function() mark_activity() end,
  })

  vim.api.nvim_create_autocmd('FocusGained', {
    group = aug,
    callback = function()
      state.focused = true
      mark_activity()
      state.last_tick_ms = vim.uv.now()
      client.refresh_status()
    end,
  })

  vim.api.nvim_create_autocmd('FocusLost', {
    group = aug,
    callback = function()
      M.flush(false)
      state.focused = false
    end,
  })

  vim.api.nvim_create_autocmd('DirChanged', {
    group = aug,
    callback = function()
      M.flush(false)
      client.refresh_status()
    end,
  })

  vim.api.nvim_create_autocmd('User', {
    group = aug,
    pattern = 'GitSignsUpdate',
    callback = function()
      local head = vim.b.gitsigns_head
      if head and head ~= '' and head ~= client.state.branch then client.refresh_status() end
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = aug,
    callback = function() M.stop() end,
  })

  local timer = vim.uv.new_timer()
  if timer then
    state.timer = timer
    timer:start(FLUSH_INTERVAL_MS, FLUSH_INTERVAL_MS, vim.schedule_wrap(function() M.flush(false) end))
  end

  client.refresh_status()
end

--- Flush final tick, close open sessions, sync touched ticket docs, and stop the background timer cleanly.
---@param opts? { sync?: boolean }
function M.stop(opts)
  if not state.started then return end
  opts = opts or {}
  if state.timer then
    pcall(state.timer.stop, state.timer)
    pcall(state.timer.close, state.timer)
    state.timer = nil
  end

  local now = vim.uv.now()
  local wall_sec = math.max(0, math.floor((now - state.last_tick_ms) / 1000))
  if wall_sec > 0 or state.has_flushed or client.state.active_issue ~= nil then
    state.last_tick_ms = now
    local cwd, payload = build_heartbeat_payload(now, wall_sec)
    local args = { 'heartbeat', '--close-session', '--sync-docs', '--cwd', cwd, '--payload', payload }
    if opts.sync then
      table.insert(args, '--json')
      client.run_sync(args, { cwd = cwd, timeout = 800 })
    elseif not client.run_detached(args, { cwd = cwd }) then
      table.insert(args, '--json')
      client.run_sync(args, { cwd = cwd, timeout = 500 })
    end
  end

  state.started = false
end

--- Start active time tracking on `key` (and move from backlog/todo to in_progress).
---@param key string
---@param cb? fun(ok: boolean)
function M.start_issue(key, cb)
  M.flush(false)
  client.run({ 'start', key, '--json' }, {}, function(ok)
    if ok then
      vim.notify('Timer started: ' .. key, vim.log.levels.INFO, { title = 'Tasks' })
      pcall(function() require('tasks.detail').reload_open() end)
    end
    if cb then cb(ok) end
  end)
end

--- Toggle pause/resume on the active timer.
function M.toggle_pause()
  local paused = client.state.timer_paused
  local sub = paused and 'resume' or 'pause'
  if not paused then M.flush(false) end
  client.run({ sub, '--json' }, {}, function(ok)
    if ok then
      vim.notify(paused and 'Task timer resumed' or 'Task timer paused', vim.log.levels.INFO, { title = 'Tasks' })
      pcall(function() require('tasks.detail').reload_open() end)
    end
  end)
end

return M
