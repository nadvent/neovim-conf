local util = require 'core.util'
local client = require 'tasks.client'
local tracker = require 'tasks.tracker'

local M = {}

local ns = vim.api.nvim_create_namespace 'tasks_board'
local state = {
  buf = nil,
  win = nil,
  help_win = nil,
  scope_all = false,
  include_done = false,
  type_filter = nil, ---@type string|nil
  line_issue = {}, ---@type table<integer, table>
  issues = {},
}

local STATUS_ORDER = { 'in_progress', 'blocked', 'in_review', 'todo', 'backlog', 'done' }
local STATUS_TITLES = {
  in_progress = 'IN PROGRESS',
  blocked = 'BLOCKED',
  in_review = 'IN REVIEW',
  todo = 'TODO',
  backlog = 'BACKLOG',
  done = 'DONE',
}

local TYPE_META = {
  bug = { icon = ' BUG ', group = 'DiagnosticError', fallback = '#d20f39', hl = 'TasksTypeBug' },
  feature = { icon = '󰛨 FEAT', group = 'DiagnosticInfo', fallback = '#1e66f5', hl = 'TasksTypeFeature' },
  task = { icon = ' TASK', group = 'DiagnosticHint', fallback = '#179299', hl = 'TasksTypeTask' },
  epic = { icon = '󰚗 EPIC', group = 'Special', fallback = '#8839ef', hl = 'TasksTypeEpic' },
  chore = { icon = '󰒓 CHOR', group = 'DiagnosticWarn', fallback = '#df8e1d', hl = 'TasksTypeChore' },
  subtask = { icon = '󰘍 SUB ', group = 'Comment', fallback = '#7c7f93', hl = 'TasksTypeSubtask' },
}

local PRIO_META = {
  p0 = { group = 'DiagnosticError', fallback = '#d20f39', hl = 'TasksPrio0' },
  p1 = { group = 'DiagnosticWarn', fallback = '#df8e1d', hl = 'TasksPrio1' },
  p2 = { group = 'DiagnosticInfo', fallback = '#1e66f5', hl = 'TasksPrio2' },
  p3 = { group = 'Comment', fallback = '#7c7f93', hl = 'TasksPrio3' },
}

--- Build Oklab-tinted pill highlights matching core.diagnostics & noctalia.
function M.setup_highlights()
  local bg_raw = util.hl_hex('Normal', 'bg')
  if not bg_raw then
    local ok_n, noctalia = pcall(require, 'core.noctalia')
    if ok_n and noctalia.get_colors then bg_raw = noctalia.get_colors().bg end
    bg_raw = bg_raw or (vim.o.background == 'dark' and '#1e1e2e' or '#eff1f5')
  end

  for _, def in pairs(TYPE_META) do
    local fg_raw = util.hl_hex(def.group, 'fg', def.fallback)
    local hex_bg, hex_fg = util.mix_oklab_hex(fg_raw, bg_raw, 0.16)
    vim.api.nvim_set_hl(0, def.hl, { bg = hex_bg, fg = hex_fg, bold = true })
  end

  for _, def in pairs(PRIO_META) do
    local fg_raw = util.hl_hex(def.group, 'fg', def.fallback)
    local hex_bg, hex_fg = util.mix_oklab_hex(fg_raw, bg_raw, 0.14)
    vim.api.nvim_set_hl(0, def.hl, { bg = hex_bg, fg = hex_fg, bold = true })
  end

  local ok_fg = util.hl_hex('DiagnosticOk', 'fg', '#40a02b')
  local act_bg, act_fg = util.mix_oklab_hex(ok_fg, bg_raw, 0.20)
  vim.api.nvim_set_hl(0, 'TasksActiveBadge', { bg = act_bg, fg = act_fg, bold = true })
  vim.api.nvim_set_hl(0, 'TasksSectionHdr', { fg = util.hl_hex('Title', 'fg', '#1e66f5'), bold = true })
  vim.api.nvim_set_hl(0, 'TasksMuted', { link = 'Comment', default = true })
end

local hl_init = false
local function ensure_hl()
  if hl_init then return end
  hl_init = true
  M.setup_highlights()
  local aug = util.augroup 'tasks_board_hl'
  vim.api.nvim_create_autocmd({ 'ColorScheme', 'User' }, {
    group = aug,
    callback = function(ev)
      if ev.event == 'User' and ev.match ~= 'NoctaliaReload' then return end
      M.setup_highlights()
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = aug,
    pattern = 'TasksUpdated',
    callback = function()
      if state.win and vim.api.nvim_win_is_valid(state.win) then M.refresh() end
    end,
  })
end

local function is_valid() return state.win and vim.api.nvim_win_is_valid(state.win) and state.buf and vim.api.nvim_buf_is_valid(state.buf) end

local function render(issues)
  if not is_valid() then return end
  state.issues = issues or {}
  state.line_issue = {}

  local grouped = {}
  for _, it in ipairs(state.issues) do
    grouped[it.status] = grouped[it.status] or {}
    table.insert(grouped[it.status], it)
  end

  local st = client.state
  local act = st.active_issue
  local timer_str = 'Idle'
  if type(act) == 'table' and act.key then
    local icon = st.timer_paused and '⏸' or '▶'
    if act.issue_type == 'bug' then
      timer_str = string.format('%s %s', icon, act.key)
    else
      timer_str = string.format('%s %s (%s)', icon, act.key, act.active_fmt or client.format_duration(act.active_seconds))
    end
  end

  local lines = {}
  local marks = {}

  local scope_lbl = state.scope_all and 'ALL PROJECTS' or (st.project_key or 'CURRENT PROJECT')
  local filter_lbl = state.type_filter and state.type_filter:upper() or 'ALL TYPES'
  local header = string.format('  Scope: %-14s  Filter: %-10s  Timer: %-18s  [? Help]', scope_lbl, filter_lbl, timer_str)
  table.insert(lines, header)
  table.insert(lines, string.rep('─', math.max(60, vim.api.nvim_win_get_width(state.win) - 2)))

  local active_key = act and act.key or nil
  local shown_any = false

  for _, status_key in ipairs(STATUS_ORDER) do
    if status_key ~= 'done' or state.include_done then
      local bucket = grouped[status_key] or {}
      if #bucket > 0 then
        shown_any = true
        table.insert(lines, '')
        local hdr_row = #lines
        table.insert(lines, string.format('  %s (%d)', STATUS_TITLES[status_key] or status_key:upper(), #bucket))
        table.insert(marks, { row = hdr_row, col_s = 0, col_e = -1, hl = 'TasksSectionHdr' })

        for _, it in ipairs(bucket) do
          local row_idx = #lines
          local tmeta = TYPE_META[it.issue_type] or TYPE_META.task
          local pmeta = PRIO_META[it.priority or 'p2'] or PRIO_META.p2
          local prio_tag = ' ' .. (it.priority or 'p2'):upper() .. ' '
          local type_tag = ' ' .. tmeta.icon .. ' '
          local is_act = it.key == active_key
          local prefix = is_act and ' ▶ ' or '   '
          local meta_parts = {}
          if it.source_file and it.source_file ~= '' then
            table.insert(meta_parts, string.format(' %s:%s', it.source_file, tostring(it.source_line or 1)))
          end
          if it.issue_type ~= 'bug' and it.active_seconds and it.active_seconds > 0 then
            table.insert(meta_parts, '⏱ ' .. client.format_duration(it.active_seconds))
          end
          if it.commit_count and it.commit_count > 0 then table.insert(meta_parts, ' ' .. tostring(it.commit_count)) end
          if it.subtasks_total and it.subtasks_total > 0 then
            table.insert(meta_parts, string.format('󰘍 %d/%d', it.subtasks_done or 0, it.subtasks_total))
          end
          if it.labels and #it.labels > 0 then table.insert(meta_parts, '#' .. table.concat(it.labels, ' #')) end
          local suffix = #meta_parts > 0 and ('  ·  ' .. table.concat(meta_parts, '  ')) or ''

          local line = string.format('%s%-9s %s %s  %s%s', prefix, it.key, type_tag, prio_tag, it.title, suffix)
          table.insert(lines, line)
          state.line_issue[row_idx + 1] = it

          local key_end = #prefix + 9
          local type_s = key_end + 1
          local type_e = type_s + #type_tag
          local prio_s = type_e + 1
          local prio_e = prio_s + #prio_tag
          if is_act then table.insert(marks, { row = row_idx, col_s = 1, col_e = key_end, hl = 'TasksActiveBadge' }) end
          table.insert(marks, { row = row_idx, col_s = type_s, col_e = type_e, hl = tmeta.hl })
          table.insert(marks, { row = row_idx, col_s = prio_s, col_e = prio_e, hl = pmeta.hl })
          if suffix ~= '' then
            table.insert(marks, { row = row_idx, col_s = #line - #suffix, col_e = #line, hl = 'TasksMuted' })
          end
        end
      end
    end
  end

  if not shown_any then
    table.insert(lines, '')
    table.insert(lines, '  No matching tasks or bugs. Press `a` to add a task or `B` to report a bug.')
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    pcall(vim.api.nvim_buf_set_extmark, state.buf, ns, m.row, m.col_s, {
      end_col = m.col_e >= 0 and m.col_e or nil,
      end_row = m.col_e < 0 and (m.row + 1) or nil,
      hl_group = m.hl,
    })
  end
end

--- Fetch issues and re-render the open board.
function M.refresh()
  local args = { 'list', '--json' }
  if state.scope_all then table.insert(args, '--all') end
  if state.include_done then table.insert(args, '--include-closed') end
  if state.type_filter then vim.list_extend(args, { '--type', state.type_filter }) end
  client.run(args, { silent = true }, function(ok, res)
    if ok and type(res) == 'table' then render(res) end
  end)
end

local function current_issue()
  if not is_valid() then return nil end
  local lnum = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.line_issue[lnum]
end

local function step_status(delta)
  local it = current_issue()
  if not it then return end
  local idx = 1
  for i, s in ipairs(STATUS_ORDER) do
    if s == it.status then
      idx = i
      break
    end
  end
  local next_idx = math.max(1, math.min(#STATUS_ORDER, idx + delta))
  local next_status = STATUS_ORDER[next_idx]
  if next_status == it.status then return end
  client.run({ 'move', it.key, next_status, '--json' }, {}, function(ok)
    if ok then
      client.refresh_status()
      M.refresh()
    end
  end)
end

local function close_help()
  if state.help_win and vim.api.nvim_win_is_valid(state.help_win) then pcall(vim.api.nvim_win_close, state.help_win, true) end
  state.help_win = nil
end

local function toggle_help()
  if state.help_win and vim.api.nvim_win_is_valid(state.help_win) then
    close_help()
    return
  end

  local help_lines = {
    '  <CR>       Jump to anchored file & line (or Markdown doc)',
    '  <S-CR>/o   Open centralized Markdown doc (~/.local/share/tsk/docs)',
    '  a / B      Create new Task / Bug',
    '  s          Start / Pause active timer on ticket',
    '  ]s / [s    Step status forward / backward',
    '  m / p      Move status / Cycle priority (P0..P3)',
    '  f / G / d  Filter type / Toggle All Projects / Toggle Done',
    '  g / D / r  Git menu / Delete ticket / Refresh board',
    '  ? / q      Toggle help / Close board',
  }
  local hbuf = vim.api.nvim_create_buf(false, true)
  vim.bo[hbuf].buftype = 'nofile'
  vim.bo[hbuf].bufhidden = 'wipe'
  vim.bo[hbuf].filetype = 'tasks_help'
  vim.api.nvim_buf_set_lines(hbuf, 0, -1, false, help_lines)
  vim.bo[hbuf].modifiable = false

  local w = 74
  local h = #help_lines
  state.help_win = vim.api.nvim_open_win(hbuf, true, {
    relative = 'editor',
    width = w,
    height = h,
    row = math.floor((vim.o.lines - h) / 2),
    col = math.floor((vim.o.columns - w) / 2),
    border = 'rounded',
    title = ' Board Keybindings ',
    title_pos = 'center',
    style = 'minimal',
    zindex = 80,
  })
  for _, k in ipairs { '?', 'q', '<Esc>' } do
    vim.keymap.set('n', k, close_help, { buffer = hbuf, silent = true, desc = 'Close Help' })
  end
end

local function bind_keys(buf)
  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = buf, silent = true, desc = desc }) end

  map('q', M.close, 'Close Task Board')
  map('<Esc>', M.close, 'Close Task Board')
  map('?', toggle_help, 'Toggle Keybindings Help')
  map('g?', toggle_help, 'Toggle Keybindings Help')
  map('r', M.refresh, 'Refresh Board')
  map('G', function()
    state.scope_all = not state.scope_all
    M.refresh()
  end, 'Toggle Project / Global Scope')
  map('d', function()
    state.include_done = not state.include_done
    M.refresh()
  end, 'Toggle Done Column')
  map('f', function()
    vim.ui.select({ 'all', 'bug', 'feature', 'task', 'epic', 'chore', 'subtask' }, { prompt = 'Filter Category:' }, function(c)
      if not c then return end
      state.type_filter = c == 'all' and nil or c
      M.refresh()
    end)
  end, 'Filter by Category')

  map('<CR>', function()
    local it = current_issue()
    if not it then return end
    M.close()
    if not client.open_issue_location(it) then
      if it.source_file and it.source_file ~= '' then
        vim.notify('File not found: ' .. it.source_file .. ' — opening Markdown doc', vim.log.levels.WARN, { title = 'Tasks' })
      else
        vim.notify('No file anchored to ' .. it.key .. ' — opening Markdown doc', vim.log.levels.INFO, { title = 'Tasks' })
      end
      require('tasks.detail').open(it.key)
    end
  end, 'Jump to File Location')
  map('<S-CR>', function()
    local it = current_issue()
    if it then require('tasks.detail').open(it.key) end
  end, 'Open Markdown Documentation')
  map('o', function()
    local it = current_issue()
    if it then require('tasks.detail').open(it.key) end
  end, 'Open Markdown Documentation')

  map('a', function() require('tasks.capture').quick_add { issue_type = 'task' } end, 'New Task')
  map('B', function() require('tasks.capture').quick_add { issue_type = 'bug' } end, 'New Bug')

  map('s', function()
    local it = current_issue()
    if not it then return end
    if client.state.active_issue and client.state.active_issue.key == it.key then
      tracker.toggle_pause()
    else
      tracker.start_issue(it.key, function() M.refresh() end)
    end
  end, 'Start/Pause Timer')

  map(']s', function() step_status(1) end, 'Next Status')
  map('[s', function() step_status(-1) end, 'Prev Status')
  map('m', function()
    local it = current_issue()
    if not it then return end
    vim.ui.select(STATUS_ORDER, { prompt = 'Move ' .. it.key .. ' to:' }, function(st)
      if not st then return end
      client.run({ 'move', it.key, st, '--json' }, {}, function(ok)
        if ok then
          client.refresh_status()
          M.refresh()
        end
      end)
    end)
  end, 'Move Status')

  map('p', function()
    local it = current_issue()
    if not it then return end
    local order = { 'p0', 'p1', 'p2', 'p3' }
    local idx = 1
    for i, pr in ipairs(order) do
      if pr == it.priority then idx = i end
    end
    local nxt = order[(idx % #order) + 1]
    client.run({ 'edit', it.key, '--priority', nxt, '--json' }, {}, function(ok)
      if ok then M.refresh() end
    end)
  end, 'Cycle Priority')

  map('g', function()
    local it = current_issue()
    if it then require('tasks').git_menu(it.key) end
  end, 'Git Actions for Ticket')

  map('D', function()
    local it = current_issue()
    if not it then return end
    vim.ui.select({ 'No', 'Yes, delete ' .. it.key }, { prompt = 'Delete ticket ' .. it.key .. '?' }, function(ans)
      if ans and ans:match '^Yes' then
        client.run({ 'delete', it.key, '--json' }, {}, function(ok)
          if ok then
            client.refresh_status()
            M.refresh()
          end
        end)
      end
    end)
  end, 'Delete Ticket')
end

--- Close the floating task board window.
function M.close()
  close_help()
  if state.win and vim.api.nvim_win_is_valid(state.win) then pcall(vim.api.nvim_win_close, state.win, true) end
  state.win = nil
end

--- Open or focus the floating Kanban / Category Task Board.
---@param opts? { all?: boolean }
function M.open(opts)
  ensure_hl()
  if opts and opts.all ~= nil then state.scope_all = opts.all end

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    M.refresh()
    return
  end

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].buftype = 'nofile'
    vim.bo[state.buf].bufhidden = 'hide'
    vim.bo[state.buf].swapfile = false
    vim.bo[state.buf].filetype = 'tasks_board'
    bind_keys(state.buf)
  end

  local width = math.min(130, math.max(72, math.floor(vim.o.columns * 0.88)))
  local height = math.min(42, math.max(18, math.floor(vim.o.lines * 0.82)))
  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = 'rounded',
    title = '  Tasks & Bugs Board ',
    title_pos = 'center',
    style = 'minimal',
  })

  vim.wo[state.win].cursorline = true
  vim.wo[state.win].wrap = false
  vim.b[state.buf].snacks_scroll = false

  render {}
  M.refresh()
end

return M
