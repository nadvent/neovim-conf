local icons = require 'icons'

local modes = {
  ['n'] = 'NORMAL',
  ['no'] = 'NORMAL',
  ['v'] = 'VISUAL',
  ['V'] = 'V-LINE',
  ['\22'] = 'V-BLOCK',
  ['s'] = 'SELECT',
  ['S'] = 'S-LINE',
  ['\19'] = 'S-BLOCK',
  ['i'] = 'INSERT',
  ['ic'] = 'INSERT',
  ['R'] = 'REPLACE',
  ['Rv'] = 'V-REPLACE',
  ['c'] = 'COMMAND',
  ['cv'] = 'EX',
  ['ce'] = 'EX',
  ['r'] = 'PROMPT',
  ['rm'] = 'MORE',
  ['r?'] = 'CONFIRM',
  ['!'] = 'SHELL',
  ['t'] = 'TERMINAL',
}

local mode_highlights = {
  StatuslineModeNormal = { fg = '#fff9e8', bg = '#1d1c11', bold = true },
  StatuslineModeInsert = { fg = '#1d1c11', bg = '#9bd85c', bold = true },
  StatuslineModeVisual = { fg = '#fff9e8', bg = '#4A1985', bold = true },
  StatuslineModeReplace = { fg = '#fff9e8', bg = '#ba1a1a', bold = true },
  StatuslineModeCommand = { fg = '#1d1c11', bg = '#00B4D8', bold = true },
  StatuslineModeTerminal = { fg = '#fff9e8', bg = '#675f22', bold = true },
  StatuslineModeOther = { fg = '#fff9e8', bg = '#4a4733', bold = true },
}

local function setup_mode_highlights()
  for group, colors in pairs(mode_highlights) do
    vim.api.nvim_set_hl(0, group, colors)
  end
end

local function get_noctalia_colors()
  local ok, noctalia = pcall(require, 'core.noctalia')
  if ok and noctalia.get_colors then
    return noctalia.get_colors()
  end
  return {
    bg = '#f6f3d5',
    fg = '#1b1b18',
    accent_primary = '#1e50ba',
    border_color = '#6f7fa1',
  }
end

local function get_shaded_bg(hex)
  if not hex or not hex:match '^#%x%x%x%x%x%x$' then
    return '#2a2820'
  end
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)

  local lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  if lum > 0.5 then
    r = math.max(0, math.floor(r * 0.92))
    g = math.max(0, math.floor(g * 0.92))
    b = math.max(0, math.floor(b * 0.92))
  else
    r = math.min(255, math.floor(r + (255 - r) * 0.10))
    g = math.min(255, math.floor(g + (255 - g) * 0.10))
    b = math.min(255, math.floor(b + (255 - b) * 0.10))
  end
  return string.format('#%02x%02x%02x', r, g, b)
end

-- LSP diagnostic highlights with shaded background
local function setup_diagnostic_highlights(c, item_bg)
  local err_hl = vim.api.nvim_get_hl(0, { name = 'DiagnosticError', link = false })
  local warn_hl = vim.api.nvim_get_hl(0, { name = 'DiagnosticWarn', link = false })
  local info_hl = vim.api.nvim_get_hl(0, { name = 'DiagnosticInfo', link = false })
  local hint_hl = vim.api.nvim_get_hl(0, { name = 'DiagnosticHint', link = false })

  vim.api.nvim_set_hl(0, 'StatuslineDiagnostic', {
    fg = c.fg or '#1b1b18',
    bg = item_bg,
  })
  vim.api.nvim_set_hl(0, 'StatuslineDiagnosticError', {
    fg = err_hl.fg and string.format('#%06x', err_hl.fg) or '#d61144',
    bg = item_bg,
    bold = true,
  })
  vim.api.nvim_set_hl(0, 'StatuslineDiagnosticWarn', {
    fg = warn_hl.fg and string.format('#%06x', warn_hl.fg) or '#e5c07b',
    bg = item_bg,
    bold = true,
  })
  vim.api.nvim_set_hl(0, 'StatuslineDiagnosticInfo', {
    fg = info_hl.fg and string.format('#%06x', info_hl.fg) or '#61afef',
    bg = item_bg,
  })
  vim.api.nvim_set_hl(0, 'StatuslineDiagnosticHint', {
    fg = hint_hl.fg and string.format('#%06x', hint_hl.fg) or '#98c379',
    bg = item_bg,
  })
end

-- Git highlights with shaded background
local function setup_git_highlights(c, item_bg)
  local branch_fg = c.accent_primary or '#136c6b'
  local add_hl = vim.api.nvim_get_hl(0, { name = 'GitSignsAdd', link = false })
  local change_hl = vim.api.nvim_get_hl(0, { name = 'GitSignsChange', link = false })
  local delete_hl = vim.api.nvim_get_hl(0, { name = 'GitSignsDelete', link = false })

  vim.api.nvim_set_hl(0, 'StatuslineGit', {
    fg = c.fg or '#1b1b18',
    bg = item_bg,
  })
  vim.api.nvim_set_hl(0, 'StatuslineGitAdd', {
    fg = add_hl.fg and string.format('#%06x', add_hl.fg) or '#507a00',
    bg = item_bg,
  })
  vim.api.nvim_set_hl(0, 'StatuslineGitChange', {
    fg = change_hl.fg and string.format('#%06x', change_hl.fg) or '#7b6f00',
    bg = item_bg,
  })
  vim.api.nvim_set_hl(0, 'StatuslineGitDelete', {
    fg = delete_hl.fg and string.format('#%06x', delete_hl.fg) or '#d81747',
    bg = item_bg,
  })
  vim.api.nvim_set_hl(0, 'StatuslineGitBranch', {
    fg = branch_fg,
    bold = true,
    bg = item_bg,
  })
end

-- Returns the current mode's display name, padded to match the window gutter width.
local function mode()
  local current_mode = vim.api.nvim_get_mode().mode
  local name = (modes[current_mode] or current_mode):upper()

  local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local wininfo = vim.fn.getwininfo(win)[1]
  local gutter_width = wininfo and wininfo.textoff or 0

  local name_w = vim.fn.strdisplaywidth(name)
  local target_w = math.max(gutter_width, name_w + 2)

  local remaining = target_w - name_w
  local pad_left = math.floor(remaining / 2)
  local pad_right = remaining - pad_left

  return string.rep(' ', pad_left) .. name .. string.rep(' ', pad_right)
end

-- Selects the highlight group for the current mode.
local function update_mode_colors()
  local current_mode = vim.api.nvim_get_mode().mode

  if current_mode == 'n' or current_mode == 'no' then
    return '%#StatuslineModeNormal#'
  elseif current_mode == 'i' or current_mode == 'ic' then
    return '%#StatuslineModeInsert#'
  elseif current_mode == 'v' or current_mode == 'V' or current_mode == '\22' or current_mode == 's' or current_mode == 'S' or current_mode == '\19' then
    return '%#StatuslineModeVisual#'
  elseif current_mode == 'R' or current_mode == 'Rv' then
    return '%#StatuslineModeReplace#'
  elseif current_mode == 'c' or current_mode == 'cv' or current_mode == 'ce' then
    return '%#StatuslineModeCommand#'
  elseif current_mode == 't' then
    return '%#StatuslineModeTerminal#'
  end

  return '%#StatuslineModeOther#'
end

-- Filetype icon with proper color highlight followed by filename
local function file_component()
  local fname = vim.fn.expand '%:t'
  local display_name = fname ~= '' and fname or '[No Name]'
  local icon, hl

  local ok, real_icons = pcall(require, 'real-icons')
  if ok then
    if fname ~= '' then
      icon, hl = real_icons.get('file', fname)
    else
      icon, hl = real_icons.get('filetype', vim.bo.filetype ~= '' and vim.bo.filetype or 'text')
    end
  end

  if not icon and _G.MiniIcons then
    icon, hl = MiniIcons.get(fname == '' and 'filetype' or 'file', fname == '' and vim.bo.filetype or fname)
  end

  if not icon then
    local ok_dev, devicons = pcall(require, 'nvim-web-devicons')
    if ok_dev then
      local ext = vim.fn.expand '%:e'
      icon, hl = devicons.get_icon(fname, ext, { default = true })
    end
  end

  icon = icon or icons.symbol_kinds.File or ''

  if hl then
    return string.format('%%#%s#%s%%#StatuslineFileName# %s', hl, icon, display_name)
  end
  return string.format('%%#StatuslineFileName#%s %s', icon, display_name)
end

-- Line information (formatted as %d/%d)
local function lineinfo()
  if vim.bo.filetype == 'alpha' then return '' end
  local current_line = vim.fn.line '.'
  local total_lines = vim.api.nvim_buf_line_count(0)
  return string.format('%%#StatuslineLineInfo# %d/%d ', current_line, total_lines)
end

-- LSP diagnostics with coloured icons and shaded background
local function lsp()
  local d_count = vim.diagnostic.count and vim.diagnostic.count(0)
  local err_count = d_count and (d_count[vim.diagnostic.severity.ERROR] or 0) or #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
  local warn_count = d_count and (d_count[vim.diagnostic.severity.WARN] or 0) or #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
  local info_count = d_count and (d_count[vim.diagnostic.severity.INFO] or 0) or #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
  local hint_count = d_count and (d_count[vim.diagnostic.severity.HINT] or 0) or #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })

  local parts = {}
  if err_count > 0 then
    table.insert(parts, '%#StatuslineDiagnosticError#' .. icons.diagnostics.ERROR .. ' ' .. err_count)
  end
  if warn_count > 0 then
    table.insert(parts, '%#StatuslineDiagnosticWarn#' .. icons.diagnostics.WARN .. ' ' .. warn_count)
  end
  if info_count > 0 then
    table.insert(parts, '%#StatuslineDiagnosticInfo#' .. icons.diagnostics.INFO .. ' ' .. info_count)
  end
  if hint_count > 0 then
    table.insert(parts, '%#StatuslineDiagnosticHint#' .. icons.diagnostics.HINT .. ' ' .. hint_count)
  end

  if #parts == 0 then
    return ''
  end

  return '%#StatuslineDiagnostic# ' .. table.concat(parts, ' ') .. ' '
end

-- Git information with aesthetic icons and shaded background
local function vcs()
  local git_info = vim.b.gitsigns_status_dict
  if not git_info or not git_info.head or git_info.head == '' then return '' end

  local git_icons = icons.git or {
    branch = '',
    added = ' ',
    changed = ' ',
    removed = ' ',
  }

  local parts = {}
  if (git_info.added or 0) > 0 then
    table.insert(parts, '%#StatuslineGitAdd#' .. git_icons.added .. git_info.added)
  end
  if (git_info.changed or 0) > 0 then
    table.insert(parts, '%#StatuslineGitChange#' .. git_icons.changed .. git_info.changed)
  end
  if (git_info.removed or 0) > 0 then
    table.insert(parts, '%#StatuslineGitDelete#' .. git_icons.removed .. git_info.removed)
  end

  table.insert(parts, '%#StatuslineGitBranch#' .. git_icons.branch .. ' ' .. git_info.head)

  return '%#StatuslineGit# ' .. table.concat(parts, ' ') .. ' '
end

-- Statusline layouts
Statusline = {}

Statusline.active = function()
  local right_items = {}

  local diag = lsp()
  if diag ~= '' then
    table.insert(right_items, diag)
  end

  local git = vcs()
  if git ~= '' then
    table.insert(right_items, git)
  end

  local info = lineinfo()
  if info ~= '' then
    table.insert(right_items, info)
  end

  local right_side = table.concat(right_items, '%#StatusLine# ')

  return table.concat {
    update_mode_colors(),
    mode(),
    '%#StatusLine# ',
    file_component(),
    '%=%#StatusLine#',
    right_side,
    right_side ~= '' and '%#StatusLine# ' or '',
  }
end

function Statusline.inactive()
  return '%#StatusLineNC#'
end

function Statusline.short()
  return '%#StatusLineNC# ' .. icons.symbol_kinds.Folder .. ' NvimTree'
end

-- Guard to check if window is a float, picker, or special buffer
local function is_ignored_window()
  -- 1. Check if current window is a floating window
  local win = vim.api.nvim_get_current_win()
  local config = vim.api.nvim_win_get_config(win)
  if config.relative and config.relative ~= '' then return true end

  -- 2. Check special buffer types
  local bt = vim.bo.buftype
  if bt == 'prompt' or bt == 'nofile' or bt == 'quickfix' or bt == 'help' then return true end

  -- 3. Check picker and special filetypes
  local ft = vim.bo.filetype
  if ft:match '^snacks_picker_' or ft:match '^Telescope' or ft == 'which-key' or ft == 'noice' then return true end

  return false
end

-- Autocmds
local id = vim.api.nvim_create_augroup('Statusline', { clear = true })

vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, {
  group = id,
  pattern = '*',
  callback = function()
    if is_ignored_window() then
      vim.opt_local.statusline = ''
      return
    end
    vim.opt_local.statusline = '%!v:lua.Statusline.active()'
  end,
})

vim.api.nvim_create_autocmd({ 'WinLeave', 'BufLeave' }, {
  group = id,
  pattern = '*',
  callback = function()
    if is_ignored_window() then
      vim.opt_local.statusline = ''
      return
    end
    vim.opt_local.statusline = '%!v:lua.Statusline.inactive()'
  end,
})

vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter', 'FileType' }, {
  group = id,
  pattern = 'NvimTree',
  callback = function() vim.opt_local.statusline = '%!v:lua.Statusline.short()' end,
})

local function setup_all_highlights()
  local c = get_noctalia_colors()
  local item_bg = get_shaded_bg(c.bg)

  setup_mode_highlights()
  setup_diagnostic_highlights(c, item_bg)
  setup_git_highlights(c, item_bg)

  vim.api.nvim_set_hl(0, 'StatuslineLineInfo', {
    fg = c.fg or '#1b1b18',
    bg = item_bg,
  })
  vim.api.nvim_set_hl(0, 'StatuslineFileName', {
    fg = c.fg or '#1b1b18',
    bg = 'none',
  })
  vim.api.nvim_set_hl(0, 'StatusLine', { bg = 'none' })
  vim.api.nvim_set_hl(0, 'StatusLineNC', { bg = 'none' })
  vim.api.nvim_set_hl(0, 'StatusLineExtra', { bg = 'none' })
end

setup_all_highlights()

vim.api.nvim_create_autocmd('ColorScheme', {
  group = id,
  callback = function()
    setup_all_highlights()
    vim.cmd 'redrawstatus'
  end,
})

vim.api.nvim_create_autocmd('User', {
  group = id,
  pattern = { 'NoctaliaReload', 'RealIconsUpdated' },
  callback = function()
    setup_all_highlights()
    vim.cmd 'redrawstatus'
  end,
})
