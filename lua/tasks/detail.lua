local client = require 'tasks.client'
local tracker = require 'tasks.tracker'

local M = {}

local state = {
  buf = nil,
  win = nil,
  key = nil,
  issue = nil,
  syncing = false,
}

local function close_detail()
  if state.win and vim.api.nvim_win_is_valid(state.win) then pcall(vim.api.nvim_win_close, state.win, true) end
  state.win = nil
end

local function reload_buf_preserving_view(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].modified then return end
  local win = vim.fn.bufwinid(buf)
  local view
  if win ~= -1 and vim.api.nvim_win_is_valid(win) then
    view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  end
  pcall(vim.api.nvim_buf_call, buf, function() vim.cmd 'silent! edit!' end)
  if view and win ~= -1 and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_call, win, function() vim.fn.winrestview(view) end)
  end
end

--- Reload currently open ticket Markdown doc from disk if unmodified.
function M.reload_open() reload_buf_preserving_view(state.buf) end

local function open_diff_float(repo_root, sha)
  client.run({ 'git', 'diff', sha, '--cwd', repo_root }, { raw = true }, function(ok, text)
    if not ok then return end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].filetype = 'diff'
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text or '', '\n', { plain = true }))
    local w = math.floor(vim.o.columns * 0.84)
    local h = math.floor(vim.o.lines * 0.78)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = w,
      height = h,
      row = math.floor((vim.o.lines - h) / 2),
      col = math.floor((vim.o.columns - w) / 2),
      border = 'rounded',
      title = '  Commit ' .. sha:sub(1, 8) .. ' ',
      title_pos = 'center',
    })
    vim.wo[win].wrap = false
    vim.keymap.set('n', 'q', function() pcall(vim.api.nvim_win_close, win, true) end, { buffer = buf, silent = true })
    vim.keymap.set('n', '<Esc>', function() pcall(vim.api.nvim_win_close, win, true) end, { buffer = buf, silent = true })
  end)
end

local function bind_doc_buffer(buf, key)
  if vim.b[buf].tasks_doc_bound then return end
  vim.b[buf].tasks_doc_bound = true

  vim.api.nvim_create_autocmd('BufWritePost', {
    buffer = buf,
    callback = function()
      if state.syncing then return end
      state.syncing = true
      local target_key = vim.b[buf].tasks_doc_key or key
      local buf_path = vim.api.nvim_buf_get_name(buf)
      client.run({ 'doc', 'sync-from-md', target_key, buf_path, '--json' }, {}, function(ok, updated)
        state.syncing = false
        if ok and type(updated) == 'table' then
          if state.key == updated.key then state.issue = updated end
          reload_buf_preserving_view(buf)
          client.refresh_status()
          vim.notify('Synced ' .. updated.key, vim.log.levels.INFO, { title = 'Tasks' })
        end
      end)
    end,
  })

  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = buf, silent = true, desc = desc }) end

  map('q', close_detail, 'Close Doc')
  map('<CR>', function()
    local line = vim.api.nvim_get_current_line()
    local sha = line:match '^%-%s+%[commit%]%s+`([0-9a-fA-F]+)`'
    if sha then
      local root = (state.issue and state.issue.project_root) or vim.fn.getcwd()
      open_diff_float(root, sha)
      return
    end
    if line:match '^>%s+Source Anchor' and state.issue then
      close_detail()
      client.open_issue_location(state.issue)
      return
    end
    vim.cmd 'normal! \r'
  end, 'Jump to Source Anchor or Commit Diff')

  local function active_key() return vim.b[buf].tasks_doc_key or state.key end

  map('s', function()
    local k = active_key()
    if k then tracker.start_issue(k) end
  end, 'Start Timer on Ticket')

  map('m', function()
    local k = active_key()
    if not k then return end
    vim.ui.select({ 'backlog', 'todo', 'in_progress', 'blocked', 'in_review', 'done', 'cancelled' }, { prompt = 'Status:' }, function(st)
      if st then client.run({ 'move', k, st, '--json' }, {}, function(ok) if ok then reload_buf_preserving_view(buf) end end) end
    end)
  end, 'Move Status')

  map('p', function()
    local k = active_key()
    if not k then return end
    vim.ui.select({ 'p0', 'p1', 'p2', 'p3' }, { prompt = 'Priority:' }, function(pr)
      if pr then client.run({ 'edit', k, '--priority', pr, '--json' }, {}, function(ok) if ok then reload_buf_preserving_view(buf) end end) end
    end)
  end, 'Set Priority')

  map('c', function()
    local k = active_key()
    if not k then return end
    client.prompt_input({ prompt = 'Comment on ' .. k .. ': ' }, function(txt)
      if txt and vim.trim(txt) ~= '' then
        client.run({ 'comment', k, vim.trim(txt), '--json' }, {}, function(ok)
          if ok then reload_buf_preserving_view(buf) end
        end)
      end
    end)
  end, 'Add Comment')

  map('l', function()
    local k = active_key()
    if not k then return end
    client.prompt_input({ prompt = 'Log manual minutes: ' }, function(mins_str)
      local mins = tonumber(mins_str)
      if not mins or mins <= 0 then return end
      client.prompt_input({ prompt = 'Note (optional): ' }, function(note)
        client.run({ 'time', 'log', k, tostring(math.floor(mins)), '--note', note or '', '--json' }, {}, function(ok)
          if ok then reload_buf_preserving_view(buf) end
        end)
      end)
    end)
  end, 'Log Manual Time')

  map('g', function()
    local k = active_key()
    if k then require('tasks').git_menu(k) end
  end, 'Git Actions')
end

--- Open persistent centralized Markdown documentation for `key` (`~/.local/share/tsk/docs/...`).
---@param key string
function M.open(key)
  if not key or key == '' then return end
  client.run({ 'doc', 'path', key, '--json' }, {}, function(ok, res)
    if not ok or type(res) ~= 'table' or not res.path then return end

    state.key = res.key or key
    state.issue = res.issue

    local buf = vim.fn.bufadd(res.path)
    local already_loaded = vim.api.nvim_buf_is_loaded(buf)
    vim.fn.bufload(buf)
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].filetype = 'markdown'
    vim.b[buf].tasks_doc_key = state.key
    vim.b[buf].snacks_scroll = false
    vim.b[buf].miniindentscope_disable = true
    bind_doc_buffer(buf, state.key)
    state.buf = buf
    if already_loaded then reload_buf_preserving_view(buf) end

    if not state.win or not vim.api.nvim_win_is_valid(state.win) then
      local w = math.min(118, math.max(70, math.floor(vim.o.columns * 0.82)))
      local h = math.min(44, math.max(20, math.floor(vim.o.lines * 0.84)))
      state.win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = w,
        height = h,
        row = math.floor((vim.o.lines - h) / 2),
        col = math.floor((vim.o.columns - w) / 2),
        border = 'rounded',
        title = ' 󰈙 ' .. state.key .. '.md ',
        title_pos = 'center',
      })
    else
      vim.api.nvim_win_set_buf(state.win, buf)
      vim.api.nvim_win_set_config(state.win, { title = ' 󰈙 ' .. state.key .. '.md ', title_pos = 'center' })
      vim.api.nvim_set_current_win(state.win)
    end

    vim.wo[state.win].wrap = true
    vim.wo[state.win].linebreak = true
  end)
end

return M
