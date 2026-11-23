local icons = require 'icons'
local util = require 'core.util'

local M = {}

---@type integer
M.ns = vim.api.nvim_create_namespace 'fancy_diagnostics'

---@type integer
M.vt_ns = vim.api.nvim_create_namespace 'fancy_diagnostics_vt'

---@type integer|nil, integer|nil
M.buffer, M.window = nil, nil

---@type { win: integer, buf: integer, lnum: integer, col: integer }|nil
M.anchor = nil

---@type string|nil
M.quad = nil

---@type table[]
M.sign_data = {}

local sev_kinds = {
  Default = { group = 'Comment', fallback = '#7c7f93' },
  Info = { group = 'DiagnosticInfo', fallback = '#179299' },
  Hint = { group = 'DiagnosticHint', fallback = '#179299' },
  Warn = { group = 'DiagnosticWarn', fallback = '#df8e1d' },
  Error = { group = 'DiagnosticError', fallback = '#d20f39' },
}

local sev_meta = {
  [vim.diagnostic.severity.ERROR] = { level = 'Error', icon = icons.diagnostics.ERROR .. ' ', hl = 'DiagnosticError' },
  [vim.diagnostic.severity.WARN] = { level = 'Warn', icon = icons.diagnostics.WARN .. ' ', hl = 'DiagnosticWarn' },
  [vim.diagnostic.severity.INFO] = { level = 'Info', icon = icons.diagnostics.INFO .. ' ', hl = 'DiagnosticInfo' },
  [vim.diagnostic.severity.HINT] = { level = 'Hint', icon = icons.diagnostics.HINT .. ' ', hl = 'DiagnosticHint' },
}

function M.update_highlights()
  local bg_raw = util.hl_hex('Normal', 'bg')
  if not bg_raw then
    local ok_n, noctalia = pcall(require, 'core.noctalia')
    if ok_n and noctalia.get_colors then bg_raw = noctalia.get_colors().bg end
    bg_raw = bg_raw or (vim.o.background == 'dark' and '#1e1e2e' or '#eff1f5')
  end

  for kind, def in pairs(sev_kinds) do
    local fg_raw = util.hl_hex(def.group, 'fg', def.fallback)
    local hex_bg, hex_fg, hex_normal_bg = util.mix_oklab_hex(fg_raw, bg_raw, 0.15)
    vim.api.nvim_set_hl(0, 'FancyDiagnostic' .. kind, { bg = hex_bg, fg = hex_fg })
    vim.api.nvim_set_hl(0, 'FancyDiagnostic' .. kind .. 'Icon', { bg = hex_fg, fg = hex_normal_bg })
  end
end

local function make_decoration(level, icon)
  local default_hl = 'FancyDiagnosticDefault'
  local default_icon_hl = 'FancyDiagnosticDefaultIcon'
  local bg_hl = 'FancyDiagnostic' .. level
  local icon_hl = 'FancyDiagnostic' .. level .. 'Icon'

  return {
    width = 3,
    line_hl_group = function(_, current) return current and bg_hl or default_hl end,
    icon = function(_, current)
      return {
        { '▌', current and icon_hl or default_icon_hl },
        { icon, current and icon_hl or default_icon_hl },
        { ' ', current and bg_hl or default_hl },
      }
    end,
    padding = function(_, current)
      return {
        { '▌', current and icon_hl or default_icon_hl },
        { '  ', current and icon_hl or default_icon_hl },
        { ' ', current and bg_hl or default_hl },
      }
    end,
  }
end

M.decorations = {}
for sev, meta in pairs(sev_meta) do
  M.decorations[sev] = make_decoration(meta.level, meta.icon)
end

local function virt_text_to_sign(virt_text)
  local out = {}
  for _, item in ipairs(virt_text) do
    if type(item[2]) == 'string' then
      table.insert(out, string.format('%%#%s#%s%%#Normal#', item[2], item[1]))
    else
      table.insert(out, item[1])
    end
  end
  return table.concat(out)
end

function M.statuscolumn()
  if vim.tbl_isempty(M.sign_data) then return '' end
  local lnum = vim.v.lnum
  local data = M.sign_data[lnum]
  if not data then return '' end
  if vim.v.virtnum == 0 and data.start_row == lnum then return virt_text_to_sign(data.icon) end
  return virt_text_to_sign(data.padding or data.icon)
end

--- Render inline end-of-line diagnostic extmarks for `bufnr`.
---@param bufnr integer
function M.render_virtual_text(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end
  vim.api.nvim_buf_clear_namespace(bufnr, M.vt_ns, 0, -1)

  if not vim.diagnostic.is_enabled { bufnr = bufnr } then return end

  local diags = vim.diagnostic.get(bufnr)
  if #diags == 0 then return end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local by_line = {}

  for _, d in ipairs(diags) do
    local entry = by_line[d.lnum]
    if not entry then
      by_line[d.lnum] = { best = d, count = 1 }
    else
      entry.count = entry.count + 1
      if (d.severity or 99) < (entry.best.severity or 99) then entry.best = d end
    end
  end

  for lnum, entry in pairs(by_line) do
    if lnum >= 0 and lnum < line_count then
      local d = entry.best
      local meta = sev_meta[d.severity] or sev_meta[vim.diagnostic.severity.INFO]
      local first_line = (d.message or ''):match '^[^\r\n]*' or ''
      first_line = vim.trim(first_line:gsub('%s+', ' '))
      if vim.fn.strdisplaywidth(first_line) > 88 then first_line = vim.fn.strcharpart(first_line, 0, 85) .. '…' end
      local extra = entry.count > 1 and string.format(' (+%d)', entry.count - 1) or ''

      pcall(vim.api.nvim_buf_set_extmark, bufnr, M.vt_ns, lnum, 0, {
        virt_text = {
          { '  ', 'Normal' },
          { '▌' .. meta.icon, 'FancyDiagnostic' .. meta.level .. 'Icon' },
          { ' ' .. first_line .. extra .. ' ', 'FancyDiagnostic' .. meta.level },
        },
        virt_text_pos = 'eol',
        hl_mode = 'combine',
        priority = 200,
      })
    end
  end
end

local function eval_prop(val, ...)
  if type(val) == 'function' then
    local ok, res = pcall(val, ...)
    if ok and res ~= nil then return res end
  end
  return val
end

local function compute_win_args(window, w, h, anchor_lnum, anchor_col)
  local screenpos = vim.fn.screenpos(window, anchor_lnum + 1, anchor_col + 1)
  local screen_width = vim.o.columns - 2
  local screen_height = vim.o.lines - vim.o.cmdheight - 2
  local srow = screenpos.row > 0 and screenpos.row or 1
  local scol = screenpos.curscol > 0 and screenpos.curscol or 1

  local quads = {
    center = {
      relative = 'editor',
      anchor = 'NW',
      row = math.ceil((vim.o.lines - h) / 2),
      col = math.ceil((vim.o.columns - w) / 2),
      border = 'rounded',
    },
    top_left = {
      condition = function() return h < srow and scol > w end,
      relative = 'win',
      border = { '╭', '─', '╮', '│', '┤', '─', '╰', '│' },
      anchor = 'SE',
      row = 0,
      col = 1,
    },
    top_right = {
      condition = function() return h < srow and scol + w <= screen_width end,
      relative = 'win',
      border = { '╭', '─', '╮', '│', '╯', '─', '├', '│' },
      anchor = 'SW',
      row = 0,
      col = 0,
    },
    bottom_left = {
      condition = function() return srow + h <= screen_height and scol > w end,
      relative = 'win',
      border = { '╭', '─', '┤', '│', '╯', '─', '╰', '│' },
      anchor = 'NE',
      row = 1,
      col = 1,
    },
    bottom_right = {
      condition = function() return srow + h <= screen_height and scol + w <= screen_width end,
      relative = 'win',
      border = { '├', '─', '╮', '│', '╯', '─', '╰', '│' },
      anchor = 'NW',
      row = 1,
      col = 0,
    },
  }

  for _, pref in ipairs { 'bottom_right', 'top_right', 'bottom_left', 'top_left' } do
    local q = quads[pref]
    if q and q.condition() then
      M.quad = pref
      return q.border, q.relative, q.anchor, q.row, q.col, { anchor_lnum, anchor_col }
    end
  end

  M.quad = 'center'
  local fb = quads.center
  return fb.border, fb.relative, fb.anchor, fb.row, fb.col, nil
end

--- Close the fancy diagnostic floating window if open.
function M.close()
  if M.window and vim.api.nvim_win_is_valid(M.window) then pcall(vim.api.nvim_win_close, M.window, true) end
  M.window = nil
  M.anchor = nil
  M.quad = nil
end

--- Open or toggle the fancy diagnostic float for the cursor line.
---@param parent_win? integer
---@param opts? { refresh?: boolean }
function M.hover(parent_win, opts)
  opts = opts or {}
  local cur_win = vim.api.nvim_get_current_win()
  if M.window and vim.api.nvim_win_is_valid(M.window) and cur_win == M.window then
    M.close()
    return
  end

  parent_win = parent_win or cur_win
  local buffer = vim.api.nvim_win_get_buf(parent_win)
  local cursor = vim.api.nvim_win_get_cursor(parent_win)
  local target_lnum = cursor[1] - 1

  local items = vim.diagnostic.get(buffer, { lnum = target_lnum })
  local is_open = M.window and vim.api.nvim_win_is_valid(M.window)

  if #items == 0 then
    M.close()
    vim.notify('No diagnostic under cursor', vim.log.levels.INFO, { title = 'Diagnostics' })
    return
  elseif not opts.refresh and is_open and M.anchor and M.anchor.buf == buffer and M.anchor.lnum == target_lnum then
    M.close()
    return
  end

  if not M.buffer or not vim.api.nvim_buf_is_valid(M.buffer) then M.buffer = vim.api.nvim_create_buf(false, true) end

  vim.b[M.buffer].snacks_scroll = false
  vim.bo[M.buffer].ft = 'markdown'
  vim.api.nvim_buf_clear_namespace(M.buffer, M.ns, 0, -1)
  vim.api.nvim_buf_set_lines(M.buffer, 0, -1, false, {})

  local max_w = math.floor(vim.o.columns * 0.45)
  local width = 20
  for _, it in ipairs(items) do
    local msg_w = vim.fn.strdisplaywidth(it.message or '') + 6
    width = math.max(width, math.min(msg_w, max_w))
  end
  local dec_width = 4

  local height_calc_cfg = {
    relative = 'editor',
    row = 0,
    col = 1,
    width = math.max(10, width - dec_width),
    height = 2,
    style = 'minimal',
    hide = true,
  }

  if not M.window or not vim.api.nvim_win_is_valid(M.window) then
    M.window = vim.api.nvim_open_win(M.buffer, false, height_calc_cfg)
  else
    vim.api.nvim_win_set_config(M.window, height_calc_cfg)
  end

  vim.wo[M.window].wrap = true
  vim.wo[M.window].linebreak = true
  vim.wo[M.window].breakindent = true

  local diagnostic_lines = 0
  local cursor_y = 1
  local ranges = {}
  local start_row = 1
  local highest_severity = nil
  local anchor_col = items[1].col or cursor[2]

  M.sign_data = {}

  for i, item in ipairs(items) do
    local from = i == 1 and 0 or -1
    local lines = vim.split(item.message, '\n', { trimempty = true })
    local c_start = item.col
    local c_end = item.end_col or item.col
    local current = cursor[2] >= c_start and cursor[2] <= c_end
    if current then
      cursor_y = diagnostic_lines + 1
      anchor_col = c_start
    end

    vim.api.nvim_buf_set_lines(M.buffer, from, -1, false, lines)

    local dec = M.decorations[item.severity] or M.decorations[vim.diagnostic.severity.INFO]
    local line_hl = eval_prop(dec.line_hl_group, item, current)
    local icon_v = eval_prop(dec.icon, item, current)
    local padding_v = eval_prop(dec.padding, item, current)

    ranges[diagnostic_lines + 1] = { item.lnum, item.col }

    vim.api.nvim_buf_set_extmark(M.buffer, M.ns, diagnostic_lines, 0, {
      end_row = diagnostic_lines + #lines,
      line_hl_group = line_hl,
    })

    diagnostic_lines = diagnostic_lines + #lines

    if not highest_severity or item.severity < highest_severity then highest_severity = item.severity end

    for _ = 1, #lines do
      table.insert(M.sign_data, {
        start_row = start_row,
        current = current,
        width = dec.width,
        icon = icon_v,
        line_hl_group = line_hl,
        padding = padding_v,
      })
    end
    start_row = start_row + #lines
  end

  local total_height = vim.api.nvim_win_text_height(M.window, { start_row = 0, end_row = -1 }).all
  local border, relative, anchor, row, col, bufpos = compute_win_args(parent_win, width, total_height, target_lnum, anchor_col)

  local win_config = {
    relative = relative or 'win',
    win = relative == 'win' and parent_win or nil,
    bufpos = relative == 'win' and bufpos or nil,
    row = row or 1,
    col = col or 0,
    width = width,
    height = total_height,
    anchor = anchor,
    border = border or 'rounded',
    style = 'minimal',
    hide = false,
  }

  M.anchor = { win = parent_win, buf = buffer, lnum = target_lnum, col = anchor_col }
  vim.api.nvim_win_set_config(M.window, win_config)
  pcall(vim.api.nvim_win_set_cursor, M.window, { cursor_y, 0 })

  vim.wo[M.window].signcolumn = 'no'
  vim.wo[M.window].statuscolumn = "%!v:lua.require'core.diagnostics'.statuscolumn()"
  vim.wo[M.window].conceallevel = 2
  vim.wo[M.window].concealcursor = 'ncv'
  vim.wo[M.window].winhl = 'FloatBorder:Comment,Normal:Normal'

  local ok_glimmer, glimmer = pcall(require, 'tiny-glimmer.lib')
  if ok_glimmer and highest_severity and sev_meta[highest_severity] then
    pcall(function()
      glimmer.cursor_line {
        name = 'fade',
        settings = {
          max_duration = 350,
          from_color = sev_meta[highest_severity].hl,
        },
      }
    end)
  end

  local function close_and_focus()
    M.close()
    if vim.api.nvim_win_is_valid(parent_win) then vim.api.nvim_set_current_win(parent_win) end
  end

  vim.keymap.set('n', '<CR>', function()
    local c = vim.api.nvim_win_get_cursor(M.window)
    local target = ranges[c[1]]
    if target then
      M.close()
      vim.api.nvim_set_current_win(parent_win)
      vim.api.nvim_win_set_cursor(parent_win, { target[1] + 1, target[2] })
    end
  end, { buffer = M.buffer, desc = 'Go to diagnostic location' })

  vim.keymap.set('n', 'q', close_and_focus, { buffer = M.buffer, desc = 'Close diagnostics window' })
  vim.keymap.set('n', '<Esc>', close_and_focus, { buffer = M.buffer, desc = 'Close diagnostics window' })
end

function M.setup()
  M.update_highlights()

  vim.diagnostic.handlers['fancy/virtual_text'] = {
    show = function(_, bufnr, _, _) M.render_virtual_text(bufnr) end,
    hide = function(_, bufnr) M.render_virtual_text(bufnr) end,
  }

  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = icons.diagnostics.ERROR .. ' ',
        [vim.diagnostic.severity.WARN] = icons.diagnostics.WARN .. ' ',
        [vim.diagnostic.severity.INFO] = icons.diagnostics.INFO .. ' ',
        [vim.diagnostic.severity.HINT] = icons.diagnostics.HINT .. ' ',
      },
    },
    virtual_text = false,
    virtual_lines = false,
    ['fancy/virtual_text'] = true,
  }

  local aug = util.augroup 'fancy_diagnostics'
  vim.api.nvim_create_autocmd({ 'ColorScheme', 'UIEnter', 'User' }, {
    group = aug,
    callback = function(ev)
      if ev.event == 'User' and ev.match ~= 'NoctaliaReload' then return end
      M.update_highlights()
    end,
  })

  vim.api.nvim_create_autocmd({ 'InsertEnter', 'BufLeave', 'WinClosed' }, {
    group = aug,
    callback = function(ev)
      if not M.window or not vim.api.nvim_win_is_valid(M.window) then return end
      if ev.event == 'WinClosed' then
        local closed = tonumber(ev.match)
        if closed == M.window or (M.anchor and closed == M.anchor.win) then M.close() end
        return
      end
      local cur_win = vim.api.nvim_get_current_win()
      if cur_win ~= M.window then M.close() end
    end,
  })
end

return M
