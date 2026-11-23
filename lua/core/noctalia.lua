local util = require 'core.util'

local M = {}

local config_home = vim.env.XDG_CONFIG_HOME or vim.fn.expand '~/.config'
M.THEME_PATH = config_home .. '/ghostty/themes/noctalia'

M.original_colorscheme = nil

---@class NoctaliaConfig
---@field profile 'noctalia'|'standard'
---@field noctalia_base_colorscheme string
---@field standard_colorscheme string|nil
---@field transparency { winbar: boolean, dropbar: boolean, tabline: boolean, bento: boolean, floating: boolean }
M.config = {
  profile = 'standard',
  noctalia_base_colorscheme = 'dayfox',
  standard_colorscheme = nil,
  transparency = {
    winbar = true,
    dropbar = true,
    tabline = true,
    bento = true,
    floating = false,
  },
}

local callbacks = {}
local watcher_handle = nil
local applying_theme = false

--- Parse Ghostty theme file.
---@param path? string
---@return table|nil
function M.parse_theme(path)
  path = path or M.THEME_PATH
  local file = io.open(path, 'r')
  if not file then return nil end

  local theme = { palette = {} }
  for line in file:lines() do
    local p_idx, p_hex = line:match '^palette%s*=%s*(%d+)%s*=%s*(#[%da-fA-F]+)'
    if p_idx and p_hex then
      theme.palette[tonumber(p_idx)] = p_hex
    else
      local key, val = line:match '^([%w%-_]+)%s*=%s*(#[%da-fA-F]+)'
      if key and val then theme[key] = val end
    end
  end
  file:close()
  return theme
end

local function get_standard_colors()
  local bg = util.hl_hex('Normal', 'bg')
  local is_light = bg and util.is_light_hex(bg, vim.o.background == 'light') or (vim.o.background == 'light')
  bg = bg or (is_light and '#ffffff' or '#181a1f')

  local fg = util.hl_hex('Normal', 'fg', is_light and '#1f2328' or '#e6edf3')
  local accent = util.hl_hex('Directory', 'fg') or util.hl_hex('Function', 'fg') or (is_light and '#2848a9' or '#61afef')
  local muted_fg = util.hl_hex('Comment', 'fg', is_light and '#7c7267' or '#8a93a5')

  local fill_bg, inactive_bg, cell_bg, sep_color, border_color
  if is_light then
    if vim.g.colors_name and vim.g.colors_name:match 'github' then
      fill_bg = '#eaeef2'
      inactive_bg = '#f6f8fa'
      cell_bg = '#f6f8fa'
      sep_color = '#d0d7de'
      border_color = '#d0d7de'
    else
      fill_bg = '#e2d9cf'
      inactive_bg = '#eae1d7'
      cell_bg = '#eae1d7'
      sep_color = '#d5ccc0'
      border_color = '#b8ada0'
    end
  else
    fill_bg = '#181a1f'
    inactive_bg = '#21252b'
    cell_bg = '#21252b'
    sep_color = '#2c313a'
    border_color = '#3e4451'
  end

  return {
    bg = bg,
    fg = fg,
    fill_bg = fill_bg,
    inactive_bg = inactive_bg,
    cell_bg = cell_bg,
    sep_color = sep_color,
    border_color = border_color,
    accent = accent,
    muted_fg = muted_fg,
    is_light = is_light,
  }
end

--- Get resolved colors table for the active profile.
---@return table
function M.get_colors()
  if M.config.profile ~= 'noctalia' then
    local sc = get_standard_colors()
    return {
      bg = sc.bg,
      fg = sc.fg,
      sel_bg = sc.cell_bg,
      sel_fg = sc.fg,
      border_color = sc.border_color,
      accent_primary = sc.accent,
      accent_secondary = sc.accent,
      accent_search = '#c6003d',
      palette = {},
      raw = {},
    }
  end

  local theme = M.parse_theme(M.THEME_PATH) or { palette = {} }
  return {
    bg = theme['background'] or '#d3dff8',
    fg = theme['foreground'] or '#181b1b',
    sel_bg = theme['selection-background'] or theme.palette[0] or '#9eb8ef',
    sel_fg = theme['selection-foreground'] or theme['cursor-text'] or '#47494f',
    border_color = theme.palette[8] or '#6f7fa1',
    accent_primary = theme.palette[2] or '#1e50ba',
    accent_secondary = theme.palette[4] or '#70199a',
    accent_search = theme.palette[1] or '#c6003d',
    palette = theme.palette,
    raw = theme,
  }
end

--- Register a callback to run whenever theme highlights reload.
---@param cb fun(colors: table)
function M.on_reload(cb) table.insert(callbacks, cb) end

local function set_hl_groups(groups)
  for group, def in pairs(groups) do
    vim.api.nvim_set_hl(0, group, def)
  end
end

--- Apply Dropbar highlights according to active profile & transparency settings.
---@param c? table
function M.apply_dropbar_highlights(c)
  local border, fg, accent, bg, cell_bg, winbar_bg

  if M.config.profile == 'noctalia' then
    c = c or M.get_colors()
    border = c.border_color or '#6f7fa1'
    fg = c.fg or '#181b1b'
    accent = c.accent_primary or '#1e50ba'
    bg = c.bg or '#d3dff8'
    local transparent = M.config.transparency.dropbar and M.config.transparency.winbar
    winbar_bg = transparent and 'none' or bg
    cell_bg = transparent and 'none' or c.sel_bg or '#b8d0f7'
  else
    local sc = get_standard_colors()
    fg = sc.fg
    accent = sc.accent
    border = sc.border_color
    bg = sc.bg
    winbar_bg = 'none'
    cell_bg = sc.cell_bg
  end

  set_hl_groups {
    WinBar = { bg = winbar_bg },
    WinBarNC = { bg = winbar_bg },
    DropBarFileName = { fg = fg, bg = 'none', underline = false },
    DropBarIconUISeparator = { fg = border, bg = 'none', underline = false },
    DropBarIconUISeparatorNC = { fg = border, bg = 'none', underline = false },
    DropBarCurrentContext = { fg = accent, bg = cell_bg, bold = true, underline = true, sp = accent },
    DropBarCurrentContextIcon = { fg = accent, bg = cell_bg, underline = true, sp = accent },
    DropBarCurrentContextName = { fg = accent, bg = cell_bg, bold = true, underline = true, sp = accent },
    DropBarHover = { fg = accent, bg = cell_bg, bold = true, underline = true, sp = accent },
    DropBarMenuFloatBorder = { fg = border, bg = bg },
    DropBarMenuNormalFloat = { fg = fg, bg = bg },
  }
end

--- Apply comprehensive UI theme (WinBar, TabLine, DropBar, Bento).
---@param c? table
function M.apply_ui_theme(c)
  if M.config.profile ~= 'noctalia' then
    M.apply_dropbar_highlights()
    local sc = get_standard_colors()
    set_hl_groups {
      TabLineFill = { bg = sc.fill_bg },
      TabLine = { bg = sc.fill_bg },
      BentoNormal = { bg = sc.fill_bg },
    }
    return
  end

  c = c or M.get_colors()
  local sep = c.border_color or '#6f7fa1'
  local transparent = M.config.transparency.tabline
  local tabline_bg = transparent and 'none' or c.bg

  set_hl_groups {
    TabLineFill = { bg = tabline_bg, underline = transparent, sp = sep },
    TabLine = { bg = tabline_bg, underline = transparent, sp = sep },
    BentoNormal = { bg = tabline_bg, underline = transparent, sp = sep },
  }

  M.apply_dropbar_highlights(c)
end

local function notify_reload(colors)
  for _, cb in ipairs(callbacks) do
    pcall(cb, colors)
  end
  vim.api.nvim_exec_autocmds('User', { pattern = 'NoctaliaReload' })
end

--- Apply core UI & picker highlight groups for the Noctalia profile.
function M.apply()
  if M.config.profile ~= 'noctalia' then return end

  local c = M.get_colors()
  local float_bg = M.config.transparency.floating and 'none' or c.bg

  set_hl_groups {
    Visual = { bg = c.sel_bg, fg = c.sel_fg },
    VisualNOS = { bg = c.sel_bg, fg = c.sel_fg },

    NormalFloat = { bg = float_bg, fg = c.fg },
    FloatBorder = { bg = float_bg, fg = c.border_color },
    FloatTitle = { bg = float_bg, fg = c.accent_primary, bold = true },

    MiniPickNormal = { bg = c.bg, fg = c.fg },
    MiniPickBorder = { bg = c.bg, fg = c.border_color },
    MiniPickBorderBusy = { bg = c.bg, fg = c.accent_secondary },
    MiniPickBorderText = { bg = c.bg, fg = c.accent_primary, bold = true },
    MiniPickHeader = { bg = c.bg, fg = c.accent_primary, bold = true },
    MiniPickPath = { bg = c.bg, fg = c.border_color },
    MiniPickMatchCurrent = { bg = c.sel_bg, fg = c.sel_fg, bold = true },
    MiniPickMatchMarked = { bg = c.sel_bg, fg = c.accent_secondary, bold = true },
    MiniPickMatchRanges = { fg = c.accent_search, bold = true },
    MiniPickPrompt = { bg = c.bg, fg = c.accent_primary, bold = true },
    MiniPickPromptPrefix = { bg = c.bg, fg = c.accent_primary, bold = true },
    MiniPickPromptCaret = { bg = c.bg, fg = c.accent_primary, bold = true },
    MiniPickPreviewLine = { bg = c.sel_bg, bold = true },
    MiniPickPreviewRegion = { bg = c.accent_search, fg = c.bg, bold = true },

    SnacksPicker = { bg = c.bg, fg = c.fg },
    SnacksPickerBorder = { bg = c.bg, fg = c.border_color },
    SnacksPickerListCursorLine = { bg = c.sel_bg, fg = c.accent_primary, bold = true },
    SnacksPickerPreviewCursorLine = { bg = c.sel_bg },
    SnacksPickerSelected = { bg = c.sel_bg, fg = c.accent_secondary, bold = true },

    FzfLuaNormal = { bg = c.bg, fg = c.fg },
    FzfLuaBorder = { bg = c.bg, fg = c.border_color },

    Pmenu = { bg = c.bg, fg = c.fg },
    PmenuSel = { bg = c.sel_bg, fg = c.sel_fg, bold = true },
    PmenuSbar = { bg = c.bg },
    PmenuThumb = { bg = c.border_color },

    WinSeparator = { fg = c.border_color, bg = 'NONE' },
    CurSearch = { bg = c.accent_primary, fg = c.bg, bold = true },
    Search = { bg = c.sel_bg, fg = c.sel_fg },
    IncSearch = { bg = c.accent_secondary, fg = c.bg, bold = true },

    MiniIndentscopeSymbol = { fg = c.border_color, nocombine = true },
    MiniIndentscopeSymbolOff = { fg = c.border_color, nocombine = true },
  }

  M.apply_ui_theme(c)
  notify_reload(c)
end

local cleared_groups = {
  'NormalFloat',
  'FloatBorder',
  'FloatTitle',
  'MiniPickNormal',
  'MiniPickBorderBusy',
  'MiniPickHeader',
  'MiniPickMatchMarked',
  'MiniPickMatchRanges',
  'MiniPickPrompt',
  'SnacksPicker',
  'SnacksPickerBorder',
  'FzfLuaNormal',
  'FzfLuaBorder',
  'Pmenu',
  'PmenuSel',
  'PmenuSbar',
  'PmenuThumb',
  'WinSeparator',
  'CurSearch',
  'Search',
  'IncSearch',
  'MiniIndentscopeSymbol',
  'MiniIndentscopeSymbolOff',
}

--- Clear Noctalia overrides and apply standard UI & picker highlights.
function M.apply_standard()
  for _, g in ipairs(cleared_groups) do
    vim.api.nvim_set_hl(0, g, {})
  end

  local sc = get_standard_colors()
  if sc.is_light then
    set_hl_groups {
      Visual = { bg = '#cfe0f7', fg = '#181b1b' },
      VisualNOS = { bg = '#cfe0f7', fg = '#181b1b' },
      CursorLine = { bg = '#eee6dd' },
      MiniPickBorder = { link = 'FloatBorder' },
      MiniPickBorderText = { link = 'FloatTitle' },
      MiniPickPath = { link = 'Comment' },
      MiniPickMatchCurrent = { bg = '#dce6f8', fg = '#1e50ba', bold = true },
      MiniPickPromptPrefix = { fg = '#1e50ba', bold = true },
      MiniPickPromptCaret = { fg = '#1e50ba', bold = true },
      MiniPickPreviewLine = { bg = '#eef2ff', bold = true },
      MiniPickPreviewRegion = { bg = '#ffd580', bold = true },
      SnacksPickerListCursorLine = { bg = '#dce6f8', fg = '#1e50ba', bold = true },
      SnacksPickerPreviewCursorLine = { bg = '#e7ded3' },
      SnacksPickerSelected = { bg = '#b8d0f7', fg = '#1e50ba', bold = true },
    }
  else
    set_hl_groups {
      Visual = { bg = '#3e4451' },
      VisualNOS = { bg = '#3e4451' },
      CursorLine = { bg = '#2c313a' },
      MiniPickBorder = { link = 'FloatBorder' },
      MiniPickBorderText = { link = 'FloatTitle' },
      MiniPickPath = { link = 'Comment' },
      MiniPickMatchCurrent = { bg = '#2e3c54', fg = '#82aaff', bold = true },
      MiniPickPromptPrefix = { fg = '#82aaff', bold = true },
      MiniPickPromptCaret = { fg = '#82aaff', bold = true },
      MiniPickPreviewLine = { bg = '#26344d', bold = true },
      MiniPickPreviewRegion = { bg = '#5e4b28', bold = true },
      SnacksPickerListCursorLine = { bg = '#3e4451', fg = '#61afef', bold = true },
      SnacksPickerPreviewCursorLine = { bg = '#2c313a' },
      SnacksPickerSelected = { bg = '#3b4252', fg = '#61afef', bold = true },
    }
  end

  set_hl_groups {
    MiniIndentscopeSymbol = { fg = sc.border_color, nocombine = true },
    MiniIndentscopeSymbolOff = { fg = sc.border_color, nocombine = true },
  }

  M.apply_ui_theme()
  notify_reload(M.get_colors())
end

function M.start_watcher()
  if watcher_handle then return end
  local watch_dir = vim.fs.dirname(M.THEME_PATH)
  local target_file = vim.fs.basename(M.THEME_PATH)

  watcher_handle = vim.uv.new_fs_event()
  if watcher_handle then
    watcher_handle:start(watch_dir, {}, function(err, filename, _)
      if err then return end
      if filename == target_file or not filename then
        vim.schedule(function()
          if M.config.profile == 'noctalia' then M.apply() end
        end)
      end
    end)
  end
end

function M.stop_watcher()
  if watcher_handle then
    pcall(watcher_handle.stop, watcher_handle)
    pcall(watcher_handle.close, watcher_handle)
    watcher_handle = nil
  end
end

--- Set active theme profile.
---@param profile 'noctalia'|'standard'
---@param opts? { silent?: boolean, init?: boolean }
function M.set_profile(profile, opts)
  opts = opts or {}
  applying_theme = true

  if profile == 'noctalia' then
    M.config.profile = 'noctalia'
    pcall(function()
      pcall(vim.cmd.packadd, 'nightfox.nvim')
      require('nightfox').setup { options = { transparent = true } }
      vim.cmd.colorscheme(M.config.noctalia_base_colorscheme or 'dayfox')
    end)
    vim.api.nvim_set_hl(0, 'Normal', { bg = 'NONE' })
    vim.api.nvim_set_hl(0, 'NormalNC', { bg = 'NONE' })
    M.start_watcher()
    M.apply()
    if not opts.silent then
      vim.notify('Theme Profile: Noctalia (' .. (M.config.noctalia_base_colorscheme or 'dayfox') .. ' + Transparent Dynamic)', vim.log.levels.INFO)
    end
  else
    M.config.profile = 'standard'
    M.stop_watcher()

    local target_theme = M.config.standard_colorscheme or M.original_colorscheme or vim.g.colors_name
    if target_theme == 'dayfox' or (target_theme and target_theme:match 'fox') then
      pcall(function() require('nightfox').setup { options = { transparent = false } } end)
    end

    if target_theme and (not opts.init or vim.g.colors_name ~= target_theme) then pcall(vim.cmd.colorscheme, target_theme) end

    M.apply_standard()
    if not opts.silent then vim.notify('Theme Profile: Standard (' .. (target_theme or vim.g.colors_name or 'default') .. ')', vim.log.levels.INFO) end
  end

  applying_theme = false
end

--- Toggle between Noctalia and Standard profiles.
function M.toggle_profile()
  M.set_profile(M.config.profile == 'noctalia' and 'standard' or 'noctalia')
end

--- Setup theme profiles and watchers.
---@param opts? table
function M.setup(opts)
  if opts then M.config = vim.tbl_deep_extend('force', M.config, opts) end

  if not M.original_colorscheme or M.original_colorscheme == '' or M.original_colorscheme == 'default' then
    M.original_colorscheme = M.config.standard_colorscheme or vim.g.colors_name
  end

  M.set_profile(M.config.profile == 'noctalia' and 'noctalia' or 'standard', { silent = true, init = true })

  local aug = util.augroup 'noctalia_profile'
  vim.api.nvim_create_autocmd('FocusGained', {
    group = aug,
    callback = function()
      if M.config.profile == 'noctalia' then M.apply() end
    end,
  })

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = aug,
    callback = function()
      if applying_theme then return end
      if M.config.profile == 'noctalia' then
        M.apply()
      else
        if vim.g.colors_name and vim.g.colors_name ~= (M.config.noctalia_base_colorscheme or 'dayfox') then
          M.original_colorscheme = vim.g.colors_name
        end
        M.apply_standard()
      end
    end,
  })
end

return M
