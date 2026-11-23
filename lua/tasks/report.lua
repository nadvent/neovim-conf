local client = require 'tasks.client'

local M = {}

local state = {
  buf = nil,
  win = nil,
  days = 7,
  scope_all = false,
  session_lines = {}, ---@type table<integer, integer>
}

local function close_report()
  if state.win and vim.api.nvim_win_is_valid(state.win) then pcall(vim.api.nvim_win_close, state.win, true) end
  state.win = nil
end

local function make_bar(ratio, width)
  local filled = math.max(0, math.min(width, math.floor(ratio * width + 0.5)))
  return string.rep('█', filled) .. string.rep('░', width - filled)
end

local function render(rep)
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  state.session_lines = {}

  local lines = {
    string.format(
      '# Time & Git Footprint Report (%dd · %s)',
      tonumber(rep.days) or state.days,
      state.scope_all and 'All Projects' or (rep.project_key or 'Current Project')
    ),
    '',
    string.format(
      '> **Total Active**: `%s`  |  **Total Wall**: `%s`  |  **Focus Ratio**: `%d%%`  |  **Commits**: `%d`',
      rep.total_active_fmt or '0s',
      rep.total_wall_fmt or '0s',
      tonumber(rep.efficiency_pct) or 0,
      #(rep.commits or {})
    ),
    '> Keys: `1`/`7`/`3` Window (1d/7d/30d) | `G` Project/All | `a` Assign unassigned session | `u` Visual Kitty TUI | `q` Close',
    '',
    '## Category Breakdown (JIRA Types)',
  }

  local max_cat = 1
  for _, v in pairs(rep.by_category or {}) do
    max_cat = math.max(max_cat, tonumber(v.active) or 0)
  end
  for _, cat in ipairs { 'bug', 'feature', 'task', 'epic', 'chore', 'subtask', 'unassigned' } do
    local info = (rep.by_category or {})[cat]
    if info and (info.active > 0 or info.wall > 0) then
      local bar = make_bar(info.active / max_cat, 20)
      table.insert(lines, string.format('- `%-10s` %s  **%s** active (%d sessions)', cat, bar, client.format_duration(info.active), info.sessions))
    end
  end

  table.insert(lines, '')
  table.insert(lines, '## Top Tickets')
  if #(rep.by_issue or {}) == 0 then
    table.insert(lines, '- (No ticket-bound time recorded in this range)')
  else
    for _, it in ipairs(rep.by_issue) do
      table.insert(
        lines,
        string.format('- **%s** `[%s|%s]` %s — `%s` active', it.key, it.issue_type, it.status, it.title, client.format_duration(it.active))
      )
    end
  end

  table.insert(lines, '')
  table.insert(lines, '## Most Edited Files')
  if #(rep.top_files or {}) == 0 then
    table.insert(lines, '- (No file activity recorded)')
  else
    for _, f in ipairs(rep.top_files) do
      table.insert(lines, string.format('- `%s` — %s', f.file, f.fmt))
    end
  end

  table.insert(lines, '')
  table.insert(lines, '## Linked Git Commits')
  if #(rep.commits or {}) == 0 then
    table.insert(lines, '- (No linked commits in this range)')
  else
    for _, cm in ipairs(rep.commits) do
      table.insert(
        lines,
        string.format('- `%s` **%s** %s (+%d/-%d)', (cm.ref_value or ''):sub(1, 8), cm.issue_key, cm.summary or '', cm.insertions or 0, cm.deletions or 0)
      )
    end
  end

  local unass = rep.unassigned_sessions or {}
  if #unass > 0 then
    table.insert(lines, '')
    table.insert(lines, '## Unassigned Project Time (Press `a` on a line to attribute to a ticket)')
    for _, s in ipairs(unass) do
      table.insert(
        lines,
        string.format(
          '- `#%d` `%s` branch `%s` — %s active',
          s.id,
          (s.started_at or ''):sub(1, 16),
          s.branch ~= '' and s.branch or '-',
          client.format_duration(s.active_seconds)
        )
      )
      state.session_lines[#lines] = s.id
    end
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

--- Fetch report data and refresh buffer.
function M.refresh()
  local args = { 'report', '--days', tostring(state.days), '--json' }
  if state.scope_all then table.insert(args, '--all') end
  client.run(args, {}, function(ok, rep)
    if ok and type(rep) == 'table' then render(rep) end
  end)
end

--- Open interactive Footprint Report inside Neovim.
function M.open(opts)
  opts = opts or {}
  if opts.days then state.days = opts.days end

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].buftype = 'nofile'
    vim.bo[state.buf].bufhidden = 'hide'
    vim.bo[state.buf].filetype = 'tasks_report'

    local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = state.buf, silent = true, desc = desc }) end
    map('q', close_report, 'Close Report')
    map('<Esc>', close_report, 'Close Report')
    map('1', function()
      state.days = 1
      M.refresh()
    end, '1 Day')
    map('7', function()
      state.days = 7
      M.refresh()
    end, '7 Days')
    map('3', function()
      state.days = 30
      M.refresh()
    end, '30 Days')
    map('G', function()
      state.scope_all = not state.scope_all
      M.refresh()
    end, 'Toggle All Projects')
    map('u', function()
      close_report()
      M.open_tui()
    end, 'Open Visual Kitty TUI')
    map('a', function()
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      local sid = state.session_lines[lnum]
      if not sid then return end
      client.run({ 'list', '--all', '--json' }, {}, function(ok, issues)
        if not ok or type(issues) ~= 'table' or #issues == 0 then return end
        local choices = vim.tbl_map(function(it) return it.key .. ' | ' .. it.title end, issues)
        vim.ui.select(choices, { prompt = 'Assign session #' .. sid .. ' to:' }, function(ch)
          if not ch then return end
          local key = ch:match '^([A-Z0-9%-]+)'
          if key then
            client.run({ 'time', 'assign', tostring(sid), key, '--json' }, {}, function(ok2)
              if ok2 then M.refresh() end
            end)
          end
        end)
      end)
    end, 'Assign Unassigned Session')
  end

  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    local w = math.min(116, math.max(70, math.floor(vim.o.columns * 0.84)))
    local h = math.min(40, math.max(18, math.floor(vim.o.lines * 0.82)))
    state.win = vim.api.nvim_open_win(state.buf, true, {
      relative = 'editor',
      width = w,
      height = h,
      row = math.floor((vim.o.lines - h) / 2),
      col = math.floor((vim.o.columns - w) / 2),
      border = 'rounded',
      title = ' ⏱ Time & Git Footprint Report ',
      title_pos = 'center',
    })
    vim.wo[state.win].wrap = true
    vim.b[state.buf].snacks_scroll = false
  else
    vim.api.nvim_set_current_win(state.win)
  end

  M.refresh()
end

--- Launch external `tsk ui` TUI (uses tmux display-popup in tmux so Ghostty Kitty graphics work cleanly).
function M.open_tui()
  local cwd = vim.fn.getcwd()
  local tsk = client.bin()
  if vim.env.TMUX and vim.env.TMUX ~= '' then
    local cmd = string.format('env -u NVIM %s ui --cwd %s', vim.fn.shellescape(tsk), vim.fn.shellescape(cwd))
    vim.system({ 'tmux', 'display-popup', '-E', '-w', '90%', '-h', '88%', '-d', cwd, cmd }, {}, function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          vim.notify('tmux popup failed, falling back to terminal split', vim.log.levels.WARN, { title = 'Tasks' })
          if Snacks and Snacks.terminal then Snacks.terminal.open(tsk .. ' ui', { cwd = cwd }) end
        else
          client.refresh_status(cwd)
        end
      end)
    end)
    return
  end

  if Snacks and Snacks.terminal then
    Snacks.terminal.open(string.format('%s ui --cwd %s', vim.fn.shellescape(tsk), vim.fn.shellescape(cwd)), { cwd = cwd })
  else
    vim.cmd('terminal ' .. vim.fn.shellescape(tsk) .. ' ui')
  end
end

return M
