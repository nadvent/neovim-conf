local client = require 'tasks.client'
local tracker = require 'tasks.tracker'

local M = {}

local ISSUE_TYPES = { 'task', 'bug', 'feature', 'epic', 'chore', 'subtask' }
local PRIORITIES = { 'p1', 'p2', 'p0', 'p3' }

local function git_blame_line_async(abs_path, line_num, on_done)
  if not abs_path or abs_path == '' or vim.fn.filereadable(abs_path) ~= 1 then
    on_done(nil)
    return
  end
  local ok = pcall(vim.system, {
    'git',
    'blame',
    '-L',
    string.format('%d,%d', line_num, line_num),
    '--porcelain',
    abs_path,
  }, {
    cwd = vim.fs.dirname(abs_path),
    text = true,
    timeout = 800,
  }, function(res)
    vim.schedule(function()
      if not res or res.code ~= 0 or not res.stdout then
        on_done(nil)
        return
      end
      local sha = res.stdout:match '^(%x+)'
      local author = res.stdout:match '\nauthor ([^\n]+)'
      local summary = res.stdout:match '\nsummary ([^\n]+)'
      if not sha or sha:match '^0+$' then
        on_done(nil)
        return
      end
      on_done(string.format('%s (%s): %s', sha:sub(1, 8), author or '?', summary or ''))
    end)
  end)
  if not ok then on_done(nil) end
end

local function create_ticket(args, start_after, open_detail)
  client.run(args, {}, function(ok, created)
    if not ok or type(created) ~= 'table' or not created.key then return end
    vim.notify(string.format('Created %s [%s]: %s', created.key, created.issue_type, created.title), vim.log.levels.INFO, { title = 'Tasks' })
    client.refresh_status()
    if start_after then tracker.start_issue(created.key) end
    if open_detail then
      vim.schedule(function() require('tasks.detail').open(created.key) end)
    end
  end)
end

--- Interactive quick capture for any JIRA issue category (with automatic file/line tracking).
---@param opts? { issue_type?: string, start?: boolean, project?: string, parent?: string, file?: string, line?: integer, symbol?: string }
function M.quick_add(opts)
  opts = opts or {}
  local cwd = vim.fn.getcwd()
  local loc = (opts.file and { file = opts.file, line = opts.line, symbol = opts.symbol }) or client.capture_cursor_location(0, cwd)

  local function ask_priority(issue_type)
    local prio_choices = issue_type == 'bug' and { 'p1', 'p0', 'p2', 'p3' } or PRIORITIES
    vim.ui.select(prio_choices, { prompt = string.format('Priority (%s):', issue_type) }, function(prio)
      if not prio then return end
      client.prompt_input({ prompt = string.format('New %s title: ', issue_type) }, function(title)
        if not title or vim.trim(title) == '' then return end
        client.prompt_input({ prompt = 'Labels (comma-separated, optional): ' }, function(labels)
          local args = { 'add', vim.trim(title), '--type', issue_type, '--priority', prio, '--json' }
          if opts.project then vim.list_extend(args, { '--project', opts.project }) end
          if opts.parent then vim.list_extend(args, { '--parent', opts.parent }) end
          if loc.file then
            vim.list_extend(args, { '--file', loc.file, '--line', tostring(loc.line or 1) })
            if loc.symbol then vim.list_extend(args, { '--symbol', loc.symbol }) end
          end
          if labels and vim.trim(labels) ~= '' then vim.list_extend(args, { '--labels', vim.trim(labels) }) end
          create_ticket(args, opts.start == true, false)
        end)
      end)
    end)
  end

  if opts.issue_type then
    ask_priority(opts.issue_type)
  else
    vim.ui.select(ISSUE_TYPES, { prompt = 'Category / Issue Type:' }, function(chosen)
      if chosen then ask_priority(chosen) end
    end)
  end
end

--- Capture a Bug ticket anchored to the cursor line / visual selection, diagnostics, Treesitter symbol, and git blame.
function M.capture_bug_at_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local abs_path = vim.api.nvim_buf_get_name(buf)
  local mode = vim.fn.mode()
  local start_line = vim.api.nvim_win_get_cursor(0)[1]
  local end_line = start_line
  if mode == 'v' or mode == 'V' or mode == '\22' then
    local vpos = vim.fn.getpos 'v'
    local orig_start = start_line
    start_line = math.min(orig_start, vpos[2])
    end_line = math.max(orig_start, vpos[2])
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
  end

  local cwd = vim.fn.getcwd()
  local rel_path = client.buffer_relpath(buf, cwd) or vim.fn.fnamemodify(abs_path, ':t')
  local symbol = client.detect_ts_symbol(buf, start_line - 1)

  local blame_done = false
  local blame_val = nil
  local pending_submit = nil
  git_blame_line_async(abs_path, start_line, function(b)
    blame_done = true
    blame_val = b
    if pending_submit then
      local fn = pending_submit
      pending_submit = nil
      fn()
    end
  end)

  local diags = vim.diagnostic.get(buf, { lnum = start_line - 1 })
  local diag_msgs = {}
  for _, d in ipairs(diags) do
    local first = (d.message or ''):match '^[^\r\n]+'
    if first then table.insert(diag_msgs, first) end
  end

  local snippet_lines = vim.api.nvim_buf_get_lines(buf, math.max(0, start_line - 1), math.min(vim.api.nvim_buf_line_count(buf), end_line), false)
  local snippet = table.concat(snippet_lines, '\n')
  local default_title = #diag_msgs > 0 and diag_msgs[1]:sub(1, 72) or ''

  local desc_parts = {}
  if #diag_msgs > 0 then table.insert(desc_parts, 'Diagnostic:\n- ' .. table.concat(diag_msgs, '\n- ')) end
  if snippet ~= '' then
    local ft = vim.bo[buf].filetype or ''
    table.insert(desc_parts, string.format('Code (%s:%d):\n```%s\n%s\n```', rel_path, start_line, ft, snippet))
  end

  vim.ui.select({ 'p1', 'p0', 'p2', 'p3' }, { prompt = 'Bug Priority:' }, function(prio)
    if not prio then return end
    client.prompt_input({ prompt = 'Bug Title: ', default = default_title }, function(title)
      if not title or vim.trim(title) == '' then return end
      vim.ui.select({ 'Yes (start timer & open)', 'Create only' }, { prompt = 'Start timer & inspect bug?' }, function(choice)
        if not choice then return end
        local open_now = choice:match '^Yes' ~= nil
        local function submit()
          local final_parts = vim.deepcopy(desc_parts)
          if blame_val then table.insert(final_parts, 'Git Blame:\n' .. blame_val) end
          local branch = client.state.branch or ''
          local args = {
            'bug',
            vim.trim(title),
            '--priority',
            prio,
            '--severity',
            prio == 'p0' and 'blocker' or (prio == 'p1' and 'major' or 'minor'),
            '--file',
            rel_path,
            '--line',
            tostring(start_line),
            '--description',
            table.concat(final_parts, '\n\n'),
            '--json',
          }
          if symbol then vim.list_extend(args, { '--symbol', symbol }) end
          if branch ~= '' then vim.list_extend(args, { '--env', 'branch:' .. branch }) end
          create_ticket(args, open_now, open_now)
        end

        if blame_done then
          submit()
        else
          pending_submit = submit
        end
      end)
    end)
  end)
end

local COMMENT_KEYWORDS = { 'TODO', 'FIXME', 'BUG', 'ISSUE', 'HACK', 'WARN', 'PERF' }

local function extract_comment_keyword(line)
  local best_idx, best_kw, best_rest
  for _, candidate in ipairs(COMMENT_KEYWORDS) do
    local s, e = line:find('%f[%a]' .. candidate .. '%f[^%a]')
    if s and (not best_idx or s < best_idx) then
      best_idx = s
      best_kw = candidate
      best_rest = line:sub(e + 1):match '^%s*:?%s*(.*)' or ''
    end
  end
  return best_kw, best_rest
end

--- Promote an inline TODO/FIXME/BUG comment on the cursor line into a tracked ticket.
function M.promote_comment_to_ticket()
  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ''

  local kw, rest = extract_comment_keyword(line)
  if not kw then
    vim.notify('No TODO/FIXME/BUG keyword found on current line', vim.log.levels.WARN, { title = 'Tasks' })
    return
  end

  local existing_key = line:match(kw .. '%s*:?%s*%[([A-Z][A-Z0-9]+%-%d+)%]') or line:match(kw .. '%s*%(([A-Z][A-Z0-9]+%-%d+)%)')
  if existing_key then
    require('tasks.detail').open(existing_key)
    return
  end

  local itype = (kw == 'BUG' or kw == 'FIXME' or kw == 'ISSUE') and 'bug' or 'task'
  local prio = (kw == 'BUG' or kw == 'FIXME') and 'p1' or 'p2'
  local title = vim.trim(rest or '')
  if title == '' then title = string.format('%s at %s:%d', kw, vim.fn.expand '%:t', lnum) end

  local rel = client.buffer_relpath(buf, vim.fn.getcwd()) or vim.fn.expand '%:t'
  local sym = client.detect_ts_symbol(buf, lnum - 1)
  local args = {
    'add',
    title,
    '--type',
    itype,
    '--priority',
    prio,
    '--file',
    rel,
    '--line',
    tostring(lnum),
    '--json',
  }
  if sym then vim.list_extend(args, { '--symbol', sym }) end

  client.run(args, {}, function(ok, created)
    if not ok or type(created) ~= 'table' or not created.key then return end
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modifiable then
      local cur_line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
      if cur_line then
        -- Keep colon directly after keyword so todo-comments.nvim highlights continue matching
        local updated_line = cur_line:gsub('(%f[%a]' .. kw .. ')%s*:?%s*', function(word)
          local after = rest ~= '' and ' ' or ''
          return word .. ': [' .. created.key .. ']' .. after
        end, 1)
        vim.api.nvim_buf_set_lines(buf, lnum - 1, lnum, false, { updated_line })
      end
    end
    vim.notify(string.format('Promoted %s -> %s', kw, created.key), vim.log.levels.INFO, { title = 'Tasks' })
  end)
end

return M
