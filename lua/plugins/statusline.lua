local icons = require 'icons'
local util = require 'core.util'

local M = {}

local mode_map = {
  ['n'] = 'N',
  ['no'] = 'N·P',
  ['v'] = 'V',
  ['V'] = 'V·L',
  ['\22'] = 'V·B',
  ['s'] = 'S',
  ['S'] = 'S·L',
  ['\19'] = 'S·B',
  ['i'] = 'I',
  ['ic'] = 'I',
  ['R'] = 'R',
  ['Rv'] = 'V·R',
  ['c'] = 'C',
  ['cv'] = 'EX',
  ['ce'] = 'EX',
  ['r'] = 'P',
  ['rm'] = 'M',
  ['r?'] = 'C',
  ['!'] = 'SH',
  ['t'] = 'T',
}

local function get_mode_hl()
  local m = vim.api.nvim_get_mode().mode
  if m == 'n' or m == 'no' then return 'StatusLineModeNormal' end
  if m == 'i' or m == 'ic' then return 'StatusLineModeInsert' end
  if m == 'v' or m == 'V' or m == '\22' or m == 's' or m == 'S' or m == '\19' then return 'StatusLineModeVisual' end
  if m == 'R' or m == 'Rv' then return 'StatusLineModeReplace' end
  if m == 'c' or m == 'cv' or m == 'ce' or m == '!' then return 'StatusLineModeCommand' end
  if m == 't' then return 'StatusLineModeTerminal' end
  return 'StatusLineModeOther'
end

local function bar() return string.format('%%#%s#%s%%*', get_mode_hl(), icons.ui.bar) end

local function mode_label()
  local m = vim.api.nvim_get_mode().mode
  return string.format('%%#%s#%s%%*', get_mode_hl(), mode_map[m] or m)
end

local function file_info(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  local filename = path ~= '' and vim.fn.fnamemodify(path, ':t') or ''
  local display_name = filename ~= '' and filename or '[No Name]'

  local ft = vim.bo[buf].filetype
  local cat = filename ~= '' and 'file' or 'filetype'
  local target = filename ~= '' and filename or (ft ~= '' and ft or 'text')
  local icon, hl = icons.file_icon(cat, target)
  local icon_part = string.format('%%#%s#%s%%*', hl or 'StatusLineFile', icon)

  if path == '' then return string.format('  %s %%#StatusLineFile#%s%%*', icon_part, display_name) end

  local dir = vim.fn.fnamemodify(path, ':.:h')
  if dir ~= '.' and dir ~= '' then
    return string.format('  %s %%#StatusLineFile#%s%%* %%#StatusLineDir#%s %s%%*', icon_part, display_name, icons.ui.folder, dir)
  end
  return string.format('  %s %%#StatusLineFile#%s%%*', icon_part, display_name)
end

local function git_info(buf)
  local head = vim.b[buf].gitsigns_head
  if not head or head == '' then return '' end

  local status = vim.b[buf].gitsigns_status_dict or {}
  local diff = ''
  if status.added and status.added > 0 then diff = diff .. string.format(' +%d', status.added) end
  if status.changed and status.changed > 0 then diff = diff .. string.format(' ~%d', status.changed) end
  if status.removed and status.removed > 0 then diff = diff .. string.format(' -%d', status.removed) end

  return string.format('%%#StatusLineGit#%s %s%s%%*', icons.git.branch, head, diff)
end

local function task_info()
  local client = package.loaded['tasks.client']
  if not client or type(client.statusline_segment) ~= 'function' then return '' end
  local seg = client.statusline_segment()
  if not seg then return '' end
  return string.format('%%#%s#%s%%*', seg.hl, seg.text)
end

local diag_order = {
  { sev = vim.diagnostic.severity.ERROR, icon = icons.diagnostics.ERROR, hl = 'StatusLineDiagError' },
  { sev = vim.diagnostic.severity.WARN, icon = icons.diagnostics.WARN, hl = 'StatusLineDiagWarn' },
  { sev = vim.diagnostic.severity.INFO, icon = icons.diagnostics.INFO, hl = 'StatusLineDiagInfo' },
  { sev = vim.diagnostic.severity.HINT, icon = icons.diagnostics.HINT, hl = 'StatusLineDiagHint' },
}

local function diagnostics(buf)
  local counts = vim.diagnostic.count(buf)
  local parts = {}
  for _, entry in ipairs(diag_order) do
    local n = counts[entry.sev] or 0
    if n > 0 then table.insert(parts, string.format('%%#%s#%s %d%%*', entry.hl, entry.icon, n)) end
  end
  if #parts == 0 then return '' end
  return table.concat(parts, ' ')
end

local function lsp_clients(buf)
  local clients = vim.lsp.get_clients { bufnr = buf }
  if #clients == 0 then return '' end

  local names = {}
  local seen = {}
  for _, client in ipairs(clients) do
    local name = client.name
    if not name:lower():find 'copilot' and not seen[name] then
      seen[name] = true
      table.insert(names, name)
    end
  end
  if #names == 0 then return '' end
  return string.format('%%#StatusLineLsp#%s%%*', table.concat(names, ', '))
end

local function filetype_info(buf)
  local ft = vim.bo[buf].filetype
  if ft == '' then return '' end
  return string.format('%%#StatusLineFt#%s%%*', ft)
end

local function location() return string.format('%%#StatusLinePos#%s %%p%%%% / %%L%%*', icons.ui.pos) end

local function is_ignored_window(win)
  if not vim.api.nvim_win_is_valid(win) then return true end
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative and cfg.relative ~= '' then return true end

  local buf = vim.api.nvim_win_get_buf(win)
  local bt = vim.bo[buf].buftype
  if bt == 'prompt' or bt == 'nofile' or bt == 'quickfix' or bt == 'help' then return true end

  local ft = vim.bo[buf].filetype
  if ft:match '^snacks_picker_' or ft == 'which-key' or ft == 'minipick' then return true end

  return false
end

local function render_active(buf)
  local left = {}
  for _, item in ipairs { bar(), mode_label(), file_info(buf), git_info(buf), task_info() } do
    if item ~= '' then table.insert(left, item) end
  end

  local right = {}
  for _, item in ipairs { diagnostics(buf), lsp_clients(buf), filetype_info(buf), location() } do
    if item ~= '' then table.insert(right, item) end
  end

  local left_str = table.concat(left, ' ')
  local right_str = table.concat(right, ' ')
  if right_str ~= '' then return left_str .. ' %=' .. right_str .. ' ' end
  return left_str .. ' %='
end

--- Render statusline string for the window currently being drawn.
---@return string
function M.render()
  local win = vim.g.statusline_winid
  if not win or win == 0 then win = vim.api.nvim_get_current_win() end
  if is_ignored_window(win) then return '' end
  if win ~= vim.api.nvim_get_current_win() then return '%#StatusLineNC#' end
  return render_active(vim.api.nvim_win_get_buf(win))
end

local function setup_highlights()
  vim.api.nvim_set_hl(0, 'StatusLine', { bg = 'none' })
  vim.api.nvim_set_hl(0, 'StatusLineNC', { bg = 'none' })

  local ok, noctalia = pcall(require, 'core.noctalia')
  local n_colors = (ok and noctalia.get_colors) and noctalia.get_colors() or {}
  local normal_fg = n_colors.accent_primary
  if not normal_fg or normal_fg == '#000000' or normal_fg == '#101010' or normal_fg == '#ffffff' then normal_fg = '#1e50ba' end

  local err_fg = util.hl_hex('DiagnosticError', 'fg', '#ba1a1a')
  local ok_fg = util.hl_hex('DiagnosticOk', 'fg', '#507a00')
  local warn_fg = util.hl_hex('DiagnosticWarn', 'fg', '#675f22')
  local info_fg = util.hl_hex('DiagnosticInfo', 'fg', '#1e50ba')
  local hint_fg = util.hl_hex('DiagnosticHint', 'fg', '#008394')

  vim.api.nvim_set_hl(0, 'StatusLineModeNormal', { fg = normal_fg, bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineModeInsert', { fg = ok_fg, bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineModeVisual', { fg = '#7b2cbf', bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineModeReplace', { fg = err_fg, bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineModeCommand', { fg = hint_fg, bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineModeTerminal', { fg = warn_fg, bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineModeOther', { fg = '#5c6370', bg = 'none', bold = true })

  vim.api.nvim_set_hl(0, 'StatusLineMode', { fg = normal_fg, bg = 'none', bold = true, default = true })
  vim.api.nvim_set_hl(0, 'StatusLineFile', { link = 'Title', default = true })
  vim.api.nvim_set_hl(0, 'StatusLineDir', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'StatusLineGit', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'StatusLineDiagError', { fg = err_fg, bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineDiagWarn', { fg = warn_fg, bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineDiagInfo', { fg = info_fg, bg = 'none' })
  vim.api.nvim_set_hl(0, 'StatusLineDiagHint', { fg = hint_fg, bg = 'none' })
  vim.api.nvim_set_hl(0, 'StatusLineLsp', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'StatusLineFt', { link = 'Special', default = true })
  vim.api.nvim_set_hl(0, 'StatusLinePos', { link = 'DiagnosticInfo', default = true })
  vim.api.nvim_set_hl(0, 'StatusLineTaskActive', { fg = ok_fg, bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineTaskBug', { fg = err_fg, bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineTaskPaused', { fg = warn_fg, bg = 'none', bold = true })
  vim.api.nvim_set_hl(0, 'StatusLineTaskIdle', { link = 'Comment', default = true })
end

setup_highlights()

vim.o.statusline = "%!v:lua.require'plugins.statusline'.render()"

local aug = util.augroup 'statusline'
vim.api.nvim_create_autocmd('ColorScheme', {
  group = aug,
  callback = function()
    setup_highlights()
    vim.cmd.redrawstatus()
  end,
})

vim.api.nvim_create_autocmd('User', {
  group = aug,
  pattern = { 'NoctaliaReload', 'RealIconsUpdated', 'TasksUpdated' },
  callback = function(ev)
    if ev.match == 'NoctaliaReload' then setup_highlights() end
    vim.cmd.redrawstatus()
  end,
})

return M
