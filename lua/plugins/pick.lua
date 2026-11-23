local icons = require 'icons'
local util = require 'core.util'

local ok_pick, MiniPick = pcall(require, 'mini.pick')
if not ok_pick then
  pcall(vim.cmd.packadd, 'mini.nvim')
  ok_pick, MiniPick = pcall(require, 'mini.pick')
  if not ok_pick then return {} end
end

local ok_extra, MiniExtra = pcall(require, 'mini.extra')
if ok_extra then MiniExtra.setup() end

-- Extract internal H table from MiniPick.start for seamless border/title & preview updates
local H = util.get_upvalue(MiniPick.start, 'H')

local preview_win = nil
local preview_buf = nil
local last_previewed_item = nil
local is_preview_visible = true

local function is_win_valid(win) return win ~= nil and vim.api.nvim_win_is_valid(win) end
local function is_buf_valid(buf) return buf ~= nil and vim.api.nvim_buf_is_valid(buf) end

local function clean_path(p)
  if not p or p == '' then return '' end
  local s = vim.fn.fnamemodify(p, ':p'):gsub('/+$', '')
  return vim.fs.normalize(s)
end

local function fit_str(str, max_w, from_left)
  if not str then return '' end
  local len = vim.fn.strchars(str)
  if len <= max_w then return str end
  if from_left then return '…' .. vim.fn.strcharpart(str, len - max_w + 1) end
  return vim.fn.strcharpart(str, 0, max_w - 1) .. '…'
end

local function format_cwd(cwd_raw, max_w)
  if not cwd_raw or cwd_raw == '' then return '' end
  local full = clean_path(cwd_raw)
  if vim.fn.strchars(full) <= max_w then return full end
  local tilde = vim.fs.normalize(vim.fn.fnamemodify(full, ':~'))
  if vim.fn.strchars(tilde) <= max_w then return tilde end
  return fit_str(tilde, max_w, true)
end

local function get_item_info(item, cwd)
  cwd = cwd or vim.fn.getcwd()
  if not item then
    local full_cwd = clean_path(cwd)
    local folder = vim.fs.basename(full_cwd)
    if folder == '' then folder = full_cwd end
    return full_cwd, folder, 'directory', nil
  end

  local raw_path = nil
  local lnum = nil

  if type(item) == 'table' then
    if item.path then
      raw_path = item.path
      lnum = item.lnum
    elseif item.bufnr or item.buf_id or item.buf then
      local b = item.bufnr or item.buf_id or item.buf
      if is_buf_valid(b) then raw_path = vim.api.nvim_buf_get_name(b) end
    elseif item.text then
      raw_path = item.text
    end
  elseif type(item) == 'string' then
    local path_part, l = item:match '^([^%z:]+)[%z:](%d+)[%z:]%d+'
    if not path_part then path_part, l = item:match '^([^%z:]+)[%z:](%d+)' end
    if path_part then
      raw_path = path_part
      lnum = tonumber(l)
    else
      raw_path = item:match '^([^%z]+)' or item
    end
  elseif type(item) == 'number' then
    if is_buf_valid(item) then raw_path = vim.api.nvim_buf_get_name(item) end
  end

  if not raw_path or raw_path == '' then
    local full_cwd = clean_path(cwd)
    local folder = vim.fs.basename(full_cwd)
    if folder == '' then folder = full_cwd end
    return full_cwd, tostring(item or folder), 'directory', nil
  end

  if raw_path:sub(1, 1) == '~' then raw_path = vim.fs.normalize(raw_path) end

  local full_path = raw_path
  if not (full_path:sub(1, 1) == '/' or full_path:match '^%a:') then full_path = cwd .. '/' .. full_path end
  full_path = clean_path(full_path)

  local is_file = vim.fn.filereadable(full_path) == 1
  local is_dir = vim.fn.isdirectory(full_path) == 1
  local has_sep = raw_path:find '[/\\]' ~= nil

  if not (is_file or is_dir or has_sep) then
    return clean_path(cwd), tostring(item or raw_path), 'custom', nil
  end

  local name = vim.fs.basename(full_path)
  if name == '' or not name then name = full_path end
  return full_path, name, is_dir and 'directory' or 'file', lnum
end

local function compute_layout()
  local lines = vim.o.lines
  local cols = vim.o.columns
  local height = math.min(math.max(16, math.floor(0.75 * lines)), lines - 4)
  local row = math.max(1, math.floor(0.5 * (lines - height)))

  if cols < 80 or not is_preview_visible then
    local width = math.min(math.max(50, math.floor(0.85 * cols)), cols - 4)
    local start_col = math.max(1, math.floor(0.5 * (cols - (width + 2))))
    return {
      has_preview = false,
      picker = {
        relative = 'editor',
        anchor = 'NW',
        height = height,
        width = width,
        row = row,
        col = start_col,
        border = 'rounded',
      },
      preview = nil,
    }
  end

  local total_outer_width = math.min(math.max(76, math.floor(0.85 * cols)), cols - 4)
  local total_content = total_outer_width - 4
  local picker_width = math.max(35, math.floor(total_content * 0.48))
  local preview_width = total_content - picker_width
  local combined_outer = picker_width + preview_width + 4
  local start_col = math.max(1, math.floor((cols - combined_outer) / 2))
  local preview_col = start_col + picker_width + 2

  return {
    has_preview = true,
    picker = {
      relative = 'editor',
      anchor = 'NW',
      height = height,
      width = picker_width,
      row = row,
      col = start_col,
      border = 'rounded',
    },
    preview = {
      relative = 'editor',
      anchor = 'NW',
      height = height,
      width = preview_width,
      row = row,
      col = preview_col,
      border = 'rounded',
    },
  }
end

local function win_config() return compute_layout().picker end

local function close_preview_win()
  if is_win_valid(preview_win) then pcall(vim.api.nvim_win_close, preview_win, true) end
  preview_win = nil
  preview_buf = nil
  last_previewed_item = nil
end

local function open_preview_win(main_win)
  if not is_preview_visible or is_win_valid(preview_win) or not is_win_valid(main_win) then return end

  local cfg = vim.api.nvim_win_get_config(main_win)
  if not cfg.relative or cfg.relative == '' then return end

  local layout = compute_layout()
  if not layout.has_preview or not layout.preview then return end

  preview_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[preview_buf].buftype = 'nofile'
  vim.bo[preview_buf].bufhidden = 'wipe'

  preview_win = vim.api.nvim_open_win(preview_buf, false, {
    relative = 'editor',
    anchor = 'NW',
    row = layout.preview.row,
    col = layout.preview.col,
    width = layout.preview.width,
    height = layout.preview.height,
    border = layout.preview.border,
    focusable = false,
    style = 'minimal',
    title = { { ' Preview ', 'MiniPickBorderText' } },
    title_pos = 'center',
    noautocmd = true,
  })

  pcall(function()
    vim.wo[preview_win].wrap = false
    vim.wo[preview_win].cursorline = true
    vim.wo[preview_win].number = true
    vim.wo[preview_win].winhighlight = 'Normal:MiniPickNormal,FloatBorder:MiniPickBorder,FloatTitle:MiniPickBorderText'
  end)
end

local function update_preview_content(item, item_type)
  if not is_win_valid(preview_win) then return end

  if item ~= last_previewed_item then
    last_previewed_item = item
    local new_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[new_buf].buftype = 'nofile'
    vim.bo[new_buf].bufhidden = 'wipe'
    vim.api.nvim_win_set_buf(preview_win, new_buf)
    if is_buf_valid(preview_buf) and preview_buf ~= new_buf then pcall(vim.api.nvim_buf_delete, preview_buf, { force = true }) end
    preview_buf = new_buf

    if item then
      pcall(function()
        local opts = MiniPick.get_picker_opts()
        local source = opts and opts.source
        if source and source.preview then
          source.preview(preview_buf, item)
        else
          MiniPick.default_preview(preview_buf, item)
        end
        if is_win_valid(preview_win) then preview_buf = vim.api.nvim_win_get_buf(preview_win) end
      end)
    end
  end

  if is_win_valid(preview_win) then vim.wo[preview_win].number = (item_type == 'file') end
end

local function refresh_current_preview()
  local matches = MiniPick.get_picker_matches()
  local item = matches and matches.current
  local opts = MiniPick.get_picker_opts()
  local cwd = (opts and opts.source and opts.source.cwd) or vim.fn.getcwd()
  local _, _, item_type = get_item_info(item, cwd)
  update_preview_content(item, item_type)
end

local function toggle_preview_window()
  local picker_state = MiniPick.get_picker_state()
  if not picker_state or not is_win_valid(picker_state.windows.main) then return false end
  local main_win = picker_state.windows.main

  is_preview_visible = not is_preview_visible
  if not is_preview_visible then
    close_preview_win()
    pcall(vim.api.nvim_win_set_config, main_win, compute_layout().picker)
  else
    pcall(vim.api.nvim_win_set_config, main_win, compute_layout().picker)
    open_preview_win(main_win)
    refresh_current_preview()
  end
  return false
end

local function scroll_preview(direction)
  return function()
    if is_win_valid(preview_win) then
      vim.api.nvim_win_call(preview_win, function()
        local height = vim.api.nvim_win_get_height(preview_win)
        local count = math.max(1, math.floor(height / 2))
        vim.cmd('normal! ' .. count .. direction)
      end)
    end
    return false
  end
end

if H and H.picker_set_bordertext then
  local orig_bordertext = H.picker_set_bordertext
  H.picker_set_bordertext = function(picker)
    orig_bordertext(picker)

    local main_win = picker.windows.main
    if not is_win_valid(main_win) then return end

    if is_preview_visible then open_preview_win(main_win) end

    local item = picker.items and picker.items[picker.match_inds[picker.current_ind]]
    local cwd = picker.opts and picker.opts.source and picker.opts.source.cwd or vim.fn.getcwd()
    local full_path, name, item_type, lnum = get_item_info(item, cwd)

    if is_preview_visible then
      update_preview_content(item, item_type)

      if is_win_valid(preview_win) then
        local cat = item_type == 'directory' and 'directory' or 'file'
        local ic, hl = icons.file_icon(cat, full_path, { glyph_only = true })
        local icon = (ic and ic ~= '') and (ic .. ' ') or ''
        local icon_hl = hl or 'MiniPickBorderText'

        local display_title = lnum and (name .. ':' .. lnum) or name
        local p_cfg = vim.api.nvim_win_get_config(preview_win)
        display_title = fit_str(display_title, math.max(10, (p_cfg.width or 40) - 6), false)

        pcall(vim.api.nvim_win_set_config, preview_win, {
          title = {
            { ' ' .. icon, icon_hl },
            { display_title .. ' ', 'MiniPickBorderText' },
          },
          title_pos = 'center',
        })
      end
    end

    local main_cfg = vim.api.nvim_win_get_config(main_win)
    local win_w = main_cfg.width or vim.api.nvim_win_get_width(main_win)
    local info = H.picker_get_general_info(picker)
    local n_marked_text = info.n_marked == 0 and '' or (info.n_marked .. '/')
    local inds = string.format(' %s|%s|%s%s ', info.relative_current_ind, info.n_matched, n_marked_text, info.n_total)

    local top_title = main_cfg.title
    if type(top_title) == 'table' and #top_title > 0 and picker.view_state == 'main' then
      local prompt_w = 0
      for _, chunk in ipairs(top_title) do
        prompt_w = prompt_w + vim.fn.strchars(chunk[1] or '')
      end
      if win_w - prompt_w - 4 >= 15 then
        local top_cwd = format_cwd(cwd, win_w - prompt_w - 4)
        local top_pad = math.max(1, win_w - prompt_w - vim.fn.strchars(top_cwd) - 2)
        table.insert(top_title, { string.rep(' ', top_pad), 'FloatBorder' })
        table.insert(top_title, { top_cwd .. ' ', 'MiniPickPath' })
      end
    end

    pcall(vim.api.nvim_win_set_config, main_win, {
      title = top_title,
      footer = { { inds, 'MiniPickBorderText' } },
      footer_pos = 'right',
    })
  end
end

local pick_group = util.augroup 'mini_pick_preview'
vim.api.nvim_create_autocmd('User', {
  group = pick_group,
  pattern = 'MiniPickStart',
  callback = function()
    is_preview_visible = true
    last_previewed_item = nil
  end,
})

vim.api.nvim_create_autocmd('User', {
  group = pick_group,
  pattern = 'MiniPickStop',
  callback = close_preview_win,
})

vim.api.nvim_create_autocmd('VimResized', {
  group = pick_group,
  callback = function()
    local state = MiniPick.get_picker_state()
    if state and is_win_valid(state.windows.main) then
      local main_win = state.windows.main
      pcall(vim.api.nvim_win_set_config, main_win, win_config())
      if is_win_valid(preview_win) then
        close_preview_win()
        open_preview_win(main_win)
        refresh_current_preview()
      end
    end
  end,
})

MiniPick.setup {
  delay = {
    async = 10,
    busy = 50,
  },
  window = {
    config = win_config,
    prompt_prefix = ' ' .. icons.ui.search .. '  ',
    prompt_caret = icons.ui.caret,
  },
  mappings = {
    toggle_preview = '',
    toggle_preview_win = {
      char = '<Tab>',
      func = toggle_preview_window,
    },
    scroll_preview_down = {
      char = '<PageDown>',
      func = scroll_preview 'j',
    },
    scroll_preview_up = {
      char = '<PageUp>',
      func = scroll_preview 'k',
    },
  },
}

-- Defer on_choice until MiniPickStop cleanup finishes so chained vim.ui.input opens cleanly in Insert mode
vim.ui.select = function(items, select_opts, on_choice, start_opts)
  return MiniPick.ui_select(items, select_opts, function(item, idx)
    vim.schedule(function()
      if on_choice then on_choice(item, idx) end
    end)
  end, start_opts)
end

local FILES_SORT_LIMIT = 10000

local function sort_level_alpha(stritems, inds)
  local depths = {}
  local lowers = {}
  for _, idx in ipairs(inds) do
    local s = stritems[idx]
    local _, d = s:gsub('/', '')
    depths[idx] = d
    lowers[idx] = s:lower()
  end

  local out = vim.list_slice(inds)
  table.sort(out, function(a, b)
    if depths[a] ~= depths[b] then return depths[a] < depths[b] end
    if lowers[a] ~= lowers[b] then return lowers[a] < lowers[b] end
    return stritems[a] < stritems[b]
  end)
  return out
end

-- Sort empty-query file lists by directory depth first, then alphabetically (guarded at 10k files)
if type(MiniPick.builtin) == 'table' and MiniPick.builtin.files then
  local orig_files = MiniPick.builtin.files
  local function sorted_files(local_opts, opts)
    local cached_items, cached_len, cached_out

    opts = vim.tbl_deep_extend('force', {
      source = {
        match = function(stritems, inds, query)
          if not query or #query == 0 then
            if #inds > FILES_SORT_LIMIT then
              cached_items, cached_len, cached_out = nil, nil, nil
              return inds
            end
            if cached_items == stritems and cached_len == #inds and cached_out then return cached_out end
            cached_items, cached_len = stritems, #inds
            cached_out = sort_level_alpha(stritems, inds)
            return cached_out
          end

          return MiniPick.default_match(stritems, inds, query)
        end,
      },
    }, opts or {})

    return orig_files(local_opts, opts)
  end

  MiniPick.builtin.files = sorted_files
  if type(MiniPick.registry) == 'table' then MiniPick.registry.files = sorted_files end
end

-- Custom registry pickers
MiniPick.registry.todo = function(local_opts)
  local_opts = local_opts or {}
  local pattern = local_opts.keywords and ('\\b(' .. local_opts.keywords:gsub(',', '|') .. ')\\b') or '\\b(TODO|FIXME|BUG|ISSUE|NOTE|HACK|WARN|PERF)\\b'
  local globs = local_opts.globs or (local_opts.current_buffer and { vim.fn.expand '%:t' } or {})
  local name = local_opts.name or (local_opts.current_buffer and 'Buffer TODOs & Fixes' or 'TODOs & Fixes')

  return MiniPick.builtin.grep({ pattern = pattern, globs = globs }, {
    source = { name = name },
  })
end

MiniPick.registry.projects = function()
  local projects = util.list_projects()
  if #projects == 0 then
    vim.notify('No projects found in ~/Projects', vim.log.levels.WARN)
    return
  end

  return MiniPick.start {
    source = {
      name = 'Projects',
      items = projects,
      choose = function(item)
        if item then
          vim.fn.chdir(item)
          MiniPick.builtin.files({}, { source = { cwd = item } })
        end
      end,
    },
  }
end

local function make_gh_picker(subcmd, title)
  return function(local_opts)
    if vim.fn.executable 'gh' ~= 1 then
      vim.notify('GitHub CLI (gh) is not installed', vim.log.levels.WARN)
      return
    end
    local_opts = local_opts or {}
    local cmd = { 'gh', subcmd, 'list', '--limit', '50' }
    if local_opts.state then vim.list_extend(cmd, { '--state', local_opts.state }) end

    local res = vim.system(cmd):wait()
    if res.code ~= 0 then
      vim.notify('GitHub CLI failed: ' .. (res.stderr or ''), vim.log.levels.WARN)
      return
    end

    local items = {}
    for line in (res.stdout or ''):gmatch '[^\r\n]+' do
      table.insert(items, line)
    end

    return MiniPick.start {
      source = {
        name = title,
        items = items,
        choose = function(item)
          local nr = item and item:match '^#?(%d+)'
          if nr then vim.system { 'gh', subcmd, 'view', '--web', nr } end
        end,
      },
    }
  end
end

MiniPick.registry.gh_issues = make_gh_picker('issue', 'GitHub Issues')
MiniPick.registry.gh_prs = make_gh_picker('pr', 'GitHub Pull Requests')

return {
  pick = MiniPick,
  extra = ok_extra and MiniExtra or nil,
}
