local client = require 'tasks.client'

local M = {}

local initialized = false

--- Show Git actions menu for a ticket (or current active ticket).
---@param key? string
function M.git_menu(key)
  local target_key = key or (client.state.active_issue and client.state.active_issue.key)
  local choices = {}
  if target_key then
    table.insert(choices, 'Create / Checkout Git Branch for ' .. target_key)
    table.insert(choices, 'Inspect Ticket Detail & Git Diffs (' .. target_key .. ')')
    table.insert(choices, 'View Dependency Graph (' .. target_key .. ')')
  end
  table.insert(choices, 'Sync Recent Repo Commits to Tickets')
  table.insert(choices, 'Install Opt-In Git Hooks (prepare-commit-msg & post-commit)')

  vim.ui.select(choices, { prompt = 'Tasks Git Integration:' }, function(chosen)
    if not chosen then return end
    if chosen:match '^Create / Checkout Git Branch' and target_key then
      client.run({ 'git', 'branch', target_key, '--json' }, {}, function(ok, res)
        if ok and res then
          vim.notify(string.format('Branch %s (%s)', res.branch or '', res.action or ''), vim.log.levels.INFO, { title = 'Tasks Git' })
          client.refresh_status()
        end
      end)
    elseif chosen:match '^Inspect Ticket Detail' and target_key then
      require('tasks.detail').open(target_key)
    elseif chosen:match '^View Dependency Graph' and target_key then
      local tsk = client.bin()
      if vim.env.TMUX and vim.env.TMUX ~= '' then
        local cmd = string.format('env -u NVIM %s graph %s && read -r _', vim.fn.shellescape(tsk), vim.fn.shellescape(target_key))
        vim.system { 'tmux', 'display-popup', '-E', '-w', '85%', '-h', '70%', cmd }
      elseif Snacks and Snacks.terminal then
        Snacks.terminal.open(string.format('%s graph %s', vim.fn.shellescape(tsk), vim.fn.shellescape(target_key)))
      end
    elseif chosen:match '^Sync Recent Repo Commits' then
      client.run({ 'git', 'sync-commits', '--json' }, {}, function(ok, res)
        if ok and res then vim.notify(string.format('Linked %d commit(s)', tonumber(res.synced) or 0), vim.log.levels.INFO, { title = 'Tasks Git' }) end
      end)
    elseif chosen:match '^Install Opt%-In Git Hooks' then
      client.run({ 'git', 'install-hooks', '.', '--tsk-bin', client.bin(), '--json' }, {}, function(ok, res)
        if ok and res then vim.notify('Installed tsk hooks in ' .. (res.repo_root or 'repo'), vim.log.levels.INFO, { title = 'Tasks Git' }) end
      end)
    end
  end)
end

--- Open detail drawer for the currently active ticket (or prompt picker if none).
function M.open_active_detail()
  local act = client.state.active_issue
  if act and act.key then
    require('tasks.detail').open(act.key)
  else
    require('tasks.pickers').pick_issues()
  end
end

--- Register user commands, MiniPick registry hooks, and start the heartbeat tracker.
function M.setup()
  if initialized then return end
  initialized = true

  require('tasks.tracker').start()

  vim.api.nvim_create_user_command('TaskBoard', function(opts)
    require('tasks.board').open { all = opts.bang }
  end, { bang = true, desc = 'Open Task & Bug Board (! for all projects)' })

  vim.api.nvim_create_user_command('TaskList', function(opts)
    require('tasks.pickers').pick_issues { all = opts.bang }
  end, { bang = true, desc = 'Pick Tasks & Bugs (! for all projects)' })

  vim.api.nvim_create_user_command('TaskNew', function(opts)
    local itype = opts.args ~= '' and opts.args or nil
    require('tasks.capture').quick_add { issue_type = itype }
  end, { nargs = '?', desc = 'Quick capture task/bug/feature/epic' })

  vim.api.nvim_create_user_command('TaskBug', function() require('tasks.capture').capture_bug_at_cursor() end, {
    range = true,
    desc = 'Capture bug anchored to cursor/selection',
  })

  vim.api.nvim_create_user_command('TaskTimer', function() require('tasks.pickers').pick_timer() end, { desc = 'Switch or toggle active task timer' })
  vim.api.nvim_create_user_command('TaskPause', function() require('tasks.tracker').toggle_pause() end, { desc = 'Pause or resume active task timer' })
  vim.api.nvim_create_user_command('TaskReport', function() require('tasks.report').open() end, { desc = 'Open Time & Git Footprint report' })
  vim.api.nvim_create_user_command('TaskUI', function() require('tasks.report').open_tui() end, { desc = 'Open Kitty-enhanced tsk ui TUI' })
  vim.api.nvim_create_user_command('TaskGit', function(opts) M.git_menu(opts.args ~= '' and opts.args or nil) end, {
    nargs = '?',
    desc = 'Task Git integration menu',
  })
  vim.api.nvim_create_user_command('TaskGH', function() require('tasks.pickers').pick_gh_sync() end, { desc = 'Explicit GitHub Issue sync' })

  vim.api.nvim_create_user_command('TaskImportMD', function(opts)
    if opts.args == '' then
      vim.notify('Usage: :TaskImportMD <path/to/TODO.md>', vim.log.levels.WARN, { title = 'Tasks' })
      return
    end
    client.run({ 'import-md', vim.fn.expand(opts.args), '--json' }, {}, function(ok, res)
      if ok and res then
        vim.notify(string.format('Imported %d tasks into %s (source file untouched)', res.count or 0, res.project_key or 'GLOBAL'), vim.log.levels.INFO, {
          title = 'Tasks',
        })
      end
    end)
  end, { nargs = 1, complete = 'file', desc = 'Import Markdown checklist items into tsk' })

  local ok_pick, MiniPick = pcall(require, 'mini.pick')
  if ok_pick and MiniPick.registry then
    MiniPick.registry.tasks = function(local_opts) require('tasks.pickers').pick_issues(local_opts) end
    MiniPick.registry.task_bugs = function(local_opts)
      local merged = vim.tbl_extend('force', { issue_type = 'bug' }, local_opts or {})
      require('tasks.pickers').pick_issues(merged)
    end
  end
end

return M
