local client = require 'tasks.client'
local tracker = require 'tasks.tracker'

local M = {}

local function ensure_pick()
  local ok, MiniPick = pcall(require, 'mini.pick')
  if not ok then
    pcall(vim.cmd.packadd, 'mini.nvim')
    ok, MiniPick = pcall(require, 'mini.pick')
  end
  return ok and MiniPick or nil
end

local type_badge = {
  bug = ' BUG ',
  feature = '󰛨 FEAT',
  epic = '󰚗 EPIC',
  task = ' TASK',
  chore = '󰒓 CHOR',
  subtask = '󰘍 SUB ',
}

local function format_issue_preview(buf_id, item)
  if not vim.api.nvim_buf_is_valid(buf_id) or not item or not item.raw then return end
  local raw = item.raw
  local lines = {
    string.format('# %s — %s', raw.key, raw.title),
    '',
    string.format('- **Type**: `%s`  |  **Status**: `%s`  |  **Priority**: `%s`', raw.issue_type, raw.status, (raw.priority or 'p2'):upper()),
    string.format('- **Project**: `%s`%s', raw.project_key or 'GLOBAL', raw.parent_key and ('  |  **Parent**: `' .. raw.parent_key .. '`') or ''),
  }
  if raw.issue_type ~= 'bug' then
    table.insert(
      lines,
      string.format(
        '- **Time**: `%s` active / `%s` wall (%d sessions)',
        client.format_duration(raw.active_seconds),
        client.format_duration(raw.wall_seconds),
        tonumber(raw.session_count) or 0
      )
    )
  end
  table.insert(lines, string.format('- **Git**: `%d` branch(es), `%d` commit(s)', tonumber(raw.branch_count) or 0, tonumber(raw.commit_count) or 0))
  if raw.labels and #raw.labels > 0 then table.insert(lines, '- **Labels**: `' .. table.concat(raw.labels, '`, `') .. '`') end
  if raw.source_file and raw.source_file ~= '' then
    table.insert(lines, string.format('- **Source**: `%s:%s` (%s)', raw.source_file, tostring(raw.source_line or 1), raw.source_symbol or '-'))
  end
  if raw.description and raw.description ~= '' then
    table.insert(lines, '')
    table.insert(lines, '## Description')
    vim.list_extend(lines, vim.split(raw.description, '\n', { plain = true }))
  end
  if raw.repro_steps and raw.repro_steps ~= '' then
    table.insert(lines, '')
    table.insert(lines, '## Reproduction Steps')
    vim.list_extend(lines, vim.split(raw.repro_steps, '\n', { plain = true }))
  end

  vim.bo[buf_id].filetype = 'markdown'
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

--- Open `mini.pick` fuzzy picker for tasks/bugs with live preview and quick actions.
---@param opts? { all?: boolean, issue_type?: string, status?: string, include_closed?: boolean, title?: string }
function M.pick_issues(opts)
  opts = opts or {}
  local MiniPick = ensure_pick()
  if not MiniPick then
    vim.notify('mini.pick is not available', vim.log.levels.WARN, { title = 'Tasks' })
    return
  end

  local args = { 'list', '--json' }
  if opts.all then table.insert(args, '--all') end
  if opts.issue_type then vim.list_extend(args, { '--type', opts.issue_type }) end
  if opts.status then vim.list_extend(args, { '--status', opts.status }) end
  if opts.include_closed then table.insert(args, '--include-closed') end

  client.run(args, {}, function(ok, issues)
    if not ok or type(issues) ~= 'table' then return end
    if #issues == 0 then
      vim.notify('No matching tasks found. Use <leader>tc or <leader>tB to capture one.', vim.log.levels.INFO, { title = 'Tasks' })
      return
    end

    local active_key = client.state.active_issue and client.state.active_issue.key or nil
    local items = {}
    for _, it in ipairs(issues) do
      local active_mark = it.key == active_key and '▶ ' or '  '
      local f_str = (it.source_file and it.source_file ~= '') and ('  ' .. it.source_file .. ':' .. tostring(it.source_line or 1)) or ''
      local t_str = (it.issue_type ~= 'bug' and it.active_seconds and it.active_seconds > 0) and (' ⏱ ' .. client.format_duration(it.active_seconds)) or ''
      local g_str = (it.commit_count and it.commit_count > 0) and ('  ' .. it.commit_count) or ''
      local label = string.format(
        '%s%-9s %s [%-11s] %s  %s%s%s%s',
        active_mark,
        it.key,
        type_badge[it.issue_type] or it.issue_type,
        it.status,
        (it.priority or 'p2'):upper(),
        it.title,
        f_str,
        t_str,
        g_str
      )
      table.insert(items, { text = label, key = it.key, raw = it })
    end

    local function open_current_doc()
      local matches = MiniPick.get_picker_matches()
      local cur = matches and matches.current
      if cur and cur.key then
        vim.schedule(function() require('tasks.detail').open(cur.key) end)
      end
      return true
    end

    local name = opts.title or (opts.all and 'All Tasks & Bugs' or ('Project Tasks (' .. (client.state.project_key or 'CWD') .. ')'))
    MiniPick.start {
      source = {
        name = name,
        items = items,
        preview = format_issue_preview,
        choose = function(chosen)
          if not chosen or not chosen.key then return end
          vim.schedule(function()
            if not client.open_issue_location(chosen.raw) then
              require('tasks.detail').open(chosen.key)
            end
          end)
        end,
      },
      mappings = {
        open_doc = {
          char = '<S-CR>',
          func = open_current_doc,
        },
        open_doc_ctrl = {
          char = '<C-o>',
          func = open_current_doc,
        },
        start_timer = {
          char = '<C-t>',
          func = function()
            local matches = MiniPick.get_picker_matches()
            local cur = matches and matches.current
            if cur and cur.key then tracker.start_issue(cur.key) end
            return true
          end,
        },
        toggle_scope = {
          char = '<C-g>',
          func = function()
            vim.schedule(function()
              M.pick_issues(vim.tbl_extend('force', opts, { all = not opts.all, title = nil }))
            end)
            return true
          end,
        },
      },
    }
  end)
end

--- Quick 1-key timer switcher/pause picker.
function M.pick_timer()
  local MiniPick = ensure_pick()
  if not MiniPick then return end

  client.run({ 'list', '--all', '--json' }, { silent = true }, function(ok, issues)
    if not ok then issues = {} end
    local items = {}
    local active = client.state.active_issue
    if active and active.key then
      table.insert(items, {
        text = (client.state.timer_paused and '▶ Resume Timer: ' or '⏸ Pause Timer: ') .. active.key .. ' — ' .. active.title,
        action = 'toggle_pause',
      })
      table.insert(items, { text = '⏹ Stop / Clear Active Ticket Pin', action = 'stop' })
    end
    table.insert(items, { text = '+ Quick Capture New Task', action = 'new_task' })
    table.insert(items, { text = ' Capture Bug at Cursor', action = 'new_bug' })

    for _, it in ipairs(issues) do
      local dur = (it.issue_type ~= 'bug' and it.active_seconds and it.active_seconds > 0) and (' (' .. client.format_duration(it.active_seconds) .. ')') or ''
      table.insert(items, {
        text = string.format('▶ Start %-9s [%s|%s] %s%s', it.key, it.issue_type, it.status, it.title, dur),
        action = 'start',
        key = it.key,
        raw = it,
      })
    end

    MiniPick.start {
      source = {
        name = 'Task Timer Control',
        items = items,
        preview = function(buf_id, item)
          if item and item.raw then
            format_issue_preview(buf_id, item)
          elseif vim.api.nvim_buf_is_valid(buf_id) then
            vim.bo[buf_id].filetype = 'markdown'
            vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, {
              '# Task Timer Control',
              '',
              'Select an issue to start tracking active Neovim coding time against it, or pause/stop the running timer.',
            })
          end
        end,
        choose = function(chosen)
          if not chosen then return end
          if chosen.action == 'toggle_pause' then
            tracker.toggle_pause()
          elseif chosen.action == 'stop' then
            client.run({ 'stop', '--json' }, {}, function() vim.notify('Active ticket timer cleared', vim.log.levels.INFO, { title = 'Tasks' }) end)
          elseif chosen.action == 'new_task' then
            require('tasks.capture').quick_add { start = true }
          elseif chosen.action == 'new_bug' then
            require('tasks.capture').capture_bug_at_cursor()
          elseif chosen.action == 'start' and chosen.key then
            tracker.start_issue(chosen.key)
          end
        end,
      },
    }
  end)
end

--- Explicit GitHub Issues sync menu (`gh` pull / push).
function M.pick_gh_sync()
  local actions = {
    { label = '⬇ Pull open GitHub Issues into tsk (current repo)', cmd = { 'gh', 'pull', '--state', 'open', '--json' } },
    { label = '⬇ Pull all GitHub Issues into tsk (open + closed)', cmd = { 'gh', 'pull', '--state', 'all', '--json' } },
    { label = '⬆ Push active ticket to GitHub Issue', cmd = 'push_active' },
  }

  local labels = vim.tbl_map(function(a) return a.label end, actions)
  vim.ui.select(labels, { prompt = 'GitHub Sync (explicit):' }, function(chosen)
    if not chosen then return end
    for _, act in ipairs(actions) do
      if act.label == chosen then
        if act.cmd == 'push_active' then
          local act_issue = client.state.active_issue
          if not act_issue or not act_issue.key then
            vim.notify('No active ticket pinned. Start one or push from ticket detail view.', vim.log.levels.WARN, { title = 'Tasks' })
            return
          end
          client.run({ 'gh', 'push', act_issue.key, '--json' }, {}, function(ok, res)
            if ok and res then
              vim.notify(string.format('Linked %s -> GitHub #%s', act_issue.key, tostring(res.gh_issue_number or '')), vim.log.levels.INFO, { title = 'Tasks' })
            end
          end)
        else
          vim.notify('Syncing GitHub Issues...', vim.log.levels.INFO, { title = 'Tasks' })
          client.run(act.cmd, {}, function(ok, res)
            if ok and res then
              vim.notify(string.format('GH Pull (%s): %d created, %d updated', res.project_key or '', res.created or 0, res.updated or 0), vim.log.levels.INFO, { title = 'Tasks' })
            end
          end)
        end
        return
      end
    end
  end)
end

return M
