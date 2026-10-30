local M = {}

local config_home = vim.env.XDG_CONFIG_HOME or vim.fn.expand '~/.config'
M.THEME_PATH = config_home .. '/ghostty/themes/noctalia'

--- Helper to detect the colorscheme originally defined in themes.lua
local function detect_themes_colorscheme()
  if vim.g.colors_name and vim.g.colors_name ~= '' and vim.g.colors_name ~= 'default' then
    return vim.g.colors_name
  end
  local config_dir = vim.fn.stdpath 'config'
  local f = io.open(config_dir .. '/lua/core/themes.lua', 'r')
  if f then
    for line in f:lines() do
      local cs = line:match "vim%.cmd%.colorscheme%s*['\"]([^'\"]+)['\"]"
      if cs then
        f:close()
        return cs
      end
    end
    f:close()
  end
  return 'github_light'
end

-- Capture the theme set by themes.lua at load time
M.original_colorscheme = vim.g.colors_name

---@class NoctaliaConfig
---@field profile 'noctalia'|'standard'
---@field noctalia_base_colorscheme string
---@field standard_colorscheme string|nil
---@field transparency { winbar: boolean, dropbar: boolean, tabline: boolean, bufferline: boolean, floating: boolean }
M.config = {
  profile = 'standard',
  noctalia_base_colorscheme = 'dayfox',
  standard_colorscheme = nil, -- Follows original theme from themes.lua
  transparency = {
    winbar = true,
    dropbar = true,
    tabline = true,
    bufferline = true,
    floating = false,
  },
}

--- Parse Ghostty theme file
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

local get_standard_colors

--- Get resolved Noctalia colors table with palette and sensible fallbacks
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

  local bg = theme['background'] or '#d3dff8'
  local fg = theme['foreground'] or '#181b1b'
  local sel_bg = theme['selection-background'] or theme.palette[0] or '#9eb8ef'
  local sel_fg = theme['selection-foreground'] or theme['cursor-text'] or '#47494f'
  local border_color = theme.palette[8] or '#6f7fa1'
  local accent_primary = theme.palette[2] or '#1e50ba'
  local accent_secondary = theme.palette[4] or '#70199a'
  local accent_search = theme.palette[1] or '#c6003d'

  return {
    bg = bg,
    fg = fg,
    sel_bg = sel_bg,
    sel_fg = sel_fg,
    border_color = border_color,
    accent_primary = accent_primary,
    accent_secondary = accent_secondary,
    accent_search = accent_search,
    palette = theme.palette,
    raw = theme,
  }
end

local callbacks = {}

--- Register a callback to be called whenever Noctalia theme reloads
---@param cb fun(colors: table)
function M.on_reload(cb)
  table.insert(callbacks, cb)
end

--- Contrast helper for text readability
local function get_contrast_fg(hex, dark_fg, light_fg)
  dark_fg = dark_fg or '#181b1b'
  light_fg = light_fg or '#ffffff'
  local r, g, b = (hex or ''):match '^#(%x%x)(%x%x)(%x%x)$'
  if not r then return light_fg end
  local lum = (0.299 * tonumber(r, 16) + 0.587 * tonumber(g, 16) + 0.114 * tonumber(b, 16)) / 255
  return lum > 0.55 and dark_fg or light_fg
end

--- Extract and compute standard colors for polished UI
get_standard_colors = function()
  local norm = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
  local dir_hl = vim.api.nvim_get_hl(0, { name = 'Directory', link = false })
  local fn_hl = vim.api.nvim_get_hl(0, { name = 'Function', link = false })
  local comment_hl = vim.api.nvim_get_hl(0, { name = 'Comment', link = false })

  local is_light = vim.o.background == 'light'
  local bg_num = norm.bg
  local fg_num = norm.fg

  local bg
  if bg_num then
    bg = string.format('#%06x', bg_num)
    local r = tonumber(bg:sub(2, 3), 16) or 242
    local g = tonumber(bg:sub(4, 5), 16) or 233
    local b = tonumber(bg:sub(6, 7), 16) or 222
    is_light = (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5
  else
    bg = is_light and '#ffffff' or '#181a1f'
  end

  local fg = fg_num and string.format('#%06x', fg_num) or (is_light and '#1f2328' or '#e6edf3')
  local accent = (dir_hl and dir_hl.fg and string.format('#%06x', dir_hl.fg))
    or (fn_hl and fn_hl.fg and string.format('#%06x', fn_hl.fg))
    or (is_light and '#2848a9' or '#61afef')
  local muted_fg = (comment_hl and comment_hl.fg and string.format('#%06x', comment_hl.fg))
    or (is_light and '#7c7267' or '#8a93a5')

  local fill_bg, inactive_bg, cell_bg, sep_color, border_color
  if is_light then
    if vim.g.colors_name and vim.g.colors_name:match 'github' then
      fill_bg = '#eaeef2'
      inactive_bg = '#f6f8fa'
      cell_bg = '#f6f8fa'
      sep_color = '#d0d7de'
      border_color = '#d0d7de'
    else
      -- Polished Dayfox / Warm light palette
      fill_bg = '#e2d9cf'
      inactive_bg = '#eae1d7'
      cell_bg = '#eae1d7'
      sep_color = '#d5ccc0'
      border_color = '#b8ada0'
    end
  else
    -- Polished Dark palette
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

--- Apply Dropbar highlights according to active profile & transparency settings
---@param c? table
function M.apply_dropbar_highlights(c)
  local border, fg, accent, bg, cell_bg, winbar_bg, underline_color

  if M.config.profile == 'noctalia' then
    c = c or M.get_colors()
    border = c.border_color or '#6f7fa1'
    fg = c.fg or '#181b1b'
    accent = c.accent_primary or '#1e50ba'
    bg = c.bg or '#d3dff8'
    local transparent = M.config.transparency.dropbar and M.config.transparency.winbar
    winbar_bg = transparent and 'none' or bg
    cell_bg = transparent and 'none' or c.sel_bg or '#b8d0f7'
    underline_color = accent
  else
    local sc = get_standard_colors()
    fg = sc.fg
    accent = sc.accent
    border = sc.border_color
    bg = sc.bg
    winbar_bg = 'none'
    cell_bg = sc.cell_bg
    underline_color = accent
  end

  local hls = {
    WinBar = { bg = winbar_bg },
    WinBarNC = { bg = winbar_bg },
    -- Clean folder+file path without background highlighting or underline:
    DropBarFileName = { fg = fg, bg = 'none', underline = false },
    DropBarIconUISeparator = { fg = border, bg = 'none', underline = false },
    DropBarIconUISeparatorNC = { fg = border, bg = 'none', underline = false },
    -- Underline outline effect on active context cells:
    DropBarCurrentContext = { fg = accent, bg = cell_bg, bold = true, underline = true, sp = underline_color },
    DropBarCurrentContextIcon = { fg = accent, bg = cell_bg, underline = true, sp = underline_color },
    DropBarCurrentContextName = { fg = accent, bg = cell_bg, bold = true, underline = true, sp = underline_color },
    DropBarHover = { fg = accent, bg = cell_bg, bold = true, underline = true, sp = underline_color },
    DropBarMenuFloatBorder = { fg = border, bg = bg },
    DropBarMenuNormalFloat = { fg = fg, bg = bg },
  }
  for group, def in pairs(hls) do
    vim.api.nvim_set_hl(0, group, def)
  end
end

--- Generate Bufferline highlight definitions
---@param c? table
---@return table
function M.get_bufferline_highlights(c)
  if M.config.profile ~= 'noctalia' then
    local sc = get_standard_colors()
    local fill_bg = sc.fill_bg
    local inactive_bg = sc.inactive_bg
    local active_bg = sc.bg
    local accent = sc.accent
    local fg = sc.fg
    local muted_fg = sc.muted_fg

    local inactive = { fg = muted_fg, bg = inactive_bg }
    local active = { fg = fg, bg = active_bg, bold = true, sp = accent }
    local separator = { fg = fill_bg, bg = inactive_bg }
    local separator_sel = { fg = fill_bg, bg = active_bg }

    local highlights = {
      fill = { bg = fill_bg },
      background = inactive,
      indicator_visible = { fg = 'none' },
      separator_selected = separator_sel,

      duplicate = { fg = muted_fg, bg = inactive_bg, italic = true },
      duplicate_visible = { fg = muted_fg, bg = inactive_bg, italic = true },
      duplicate_selected = { fg = fg, bg = active_bg, italic = true },

      modified = { fg = '#a5222f', bg = inactive_bg },
      modified_visible = { fg = '#a5222f', bg = inactive_bg },
      modified_selected = { fg = '#a5222f', bg = active_bg },
      tab_close = { fg = '#a5222f', bg = inactive_bg },

      error = { fg = '#a5222f', bg = inactive_bg },
      error_visible = { fg = '#a5222f', bg = inactive_bg },
      error_selected = { fg = '#a5222f', bg = active_bg, bold = true },

      warning = { fg = '#a35824', bg = inactive_bg },
      warning_visible = { fg = '#a35824', bg = inactive_bg },
      warning_selected = { fg = '#a35824', bg = active_bg, bold = true },

      info = { fg = '#287980', bg = inactive_bg },
      info_visible = { fg = '#287980', bg = inactive_bg },
      info_selected = { fg = '#287980', bg = active_bg, bold = true },

      hint = { fg = '#396847', bg = inactive_bg },
      hint_visible = { fg = '#396847', bg = inactive_bg },
      hint_selected = { fg = '#396847', bg = active_bg, bold = true },
    }

    for _, key in ipairs { 'buffer_visible', 'close_button', 'close_button_visible', 'tab', 'numbers', 'numbers_visible' } do
      highlights[key] = inactive
    end
    for _, key in ipairs { 'separator', 'separator_visible', 'trunc_marker', 'offset_separator' } do
      highlights[key] = separator
    end
    for _, key in ipairs {
      'buffer_selected',
      'tab_selected',
      'numbers_selected',
    } do
      highlights[key] = active
    end
    highlights['indicator_selected'] = { fg = accent, bg = active_bg, sp = accent }
    for _, key in ipairs { 'close_button_selected', 'modified_selected' } do
      highlights[key] = { fg = accent, bg = active_bg }
    end

    return highlights
  end

  c = c or M.get_colors()
  local sep = c.border_color or '#6f7fa1'
  local accent = c.accent_primary or '#1e50ba'
  local search_accent = c.accent_search or '#c6003d'
  local active_fg = get_contrast_fg(accent, c.fg or '#181b1b', c.bg or '#ffffff')
  local palette = c.palette or {}
  local transparent = M.config.transparency.bufferline

  local function hl(opts)
    local bg = transparent and 'none' or c.bg
    return vim.tbl_extend('keep', opts or {}, { bg = bg, underline = transparent, sp = sep })
  end

  local inactive = hl { fg = sep }
  local active = hl { fg = active_fg, bg = accent, sp = accent }
  local active_bold = hl { fg = active_fg, bg = accent, sp = accent, bold = true }
  local modified = hl { fg = search_accent }
  local separator = hl { fg = sep }

  local highlights = {
    fill = hl(),
    background = inactive,
    indicator_visible = hl { fg = 'none' },
    separator_selected = hl { fg = sep, sp = accent },

    duplicate = hl { fg = c.sel_fg or '#47494f', italic = true },
    duplicate_visible = hl { fg = c.sel_fg or '#47494f', italic = true },
    duplicate_selected = hl { fg = active_fg, bg = accent, sp = accent, italic = true },

    modified = modified,
    modified_visible = modified,
    tab_close = modified,

    error = modified,
    error_visible = modified,
    warning = hl { fg = palette[3] or '#e5c07b' },
    warning_visible = hl { fg = palette[3] or '#e5c07b' },
    info = hl { fg = palette[6] or '#1b4f7e' },
    info_visible = hl { fg = palette[6] or '#1b4f7e' },
    hint = hl { fg = palette[5] or '#017979' },
    hint_visible = hl { fg = palette[5] or '#017979' },
  }

  for _, key in ipairs { 'buffer_visible', 'close_button', 'close_button_visible', 'tab', 'numbers', 'numbers_visible' } do
    highlights[key] = inactive
  end
  for _, key in ipairs { 'separator', 'separator_visible', 'trunc_marker', 'offset_separator' } do
    highlights[key] = separator
  end
  for _, key in ipairs {
    'buffer_selected',
    'indicator_selected',
    'tab_selected',
    'numbers_selected',
    'error_selected',
    'warning_selected',
    'info_selected',
    'hint_selected',
  } do
    highlights[key] = active_bold
  end
  for _, key in ipairs { 'close_button_selected', 'modified_selected' } do
    highlights[key] = active
  end

  return highlights
end

--- Apply comprehensive UI theme (WinBar, TabLine, DropBar, Bufferline)
---@param c? table
function M.apply_ui_theme(c)
  if M.config.profile ~= 'noctalia' then
    M.apply_dropbar_highlights()
    local sc = get_standard_colors()
    vim.api.nvim_set_hl(0, 'TabLineFill', { bg = sc.fill_bg })
    vim.api.nvim_set_hl(0, 'TabLine', { bg = sc.fill_bg })

    local ok, bl_hl = pcall(require, 'bufferline.highlights')
    if ok then
      for name, hl_def in pairs(M.get_bufferline_highlights()) do
        local group = bl_hl.generate_name(name)
        if group then vim.api.nvim_set_hl(0, group, hl_def) end
      end
    end
    return
  end

  c = c or M.get_colors()
  local sep = c.border_color or '#6f7fa1'
  local transparent = M.config.transparency.tabline

  local tabline_bg = transparent and 'none' or c.bg
  vim.api.nvim_set_hl(0, 'TabLineFill', { bg = tabline_bg, underline = transparent, sp = sep })
  vim.api.nvim_set_hl(0, 'TabLine', { bg = tabline_bg, underline = transparent, sp = sep })

  M.apply_dropbar_highlights(c)

  local ok, bl_hl = pcall(require, 'bufferline.highlights')
  if ok then
    for name, hl_def in pairs(M.get_bufferline_highlights(c)) do
      local group = bl_hl.generate_name(name)
      if group then vim.api.nvim_set_hl(0, group, hl_def) end
    end
  end
end

--- Apply core UI highlight groups for Noctalia profile
function M.apply()
  if M.config.profile ~= 'noctalia' then return end

  local colors = M.get_colors()
  local bg = colors.bg
  local fg = colors.fg
  local sel_bg = colors.sel_bg
  local sel_fg = colors.sel_fg
  local border_color = colors.border_color
  local accent_primary = colors.accent_primary
  local accent_secondary = colors.accent_secondary
  local accent_search = colors.accent_search

  -- 1. Visual Selection
  vim.api.nvim_set_hl(0, 'Visual', { bg = sel_bg, fg = sel_fg })
  vim.api.nvim_set_hl(0, 'VisualNOS', { bg = sel_bg, fg = sel_fg })

  -- 2. General Floating Windows
  local float_bg = M.config.transparency.floating and 'none' or bg
  vim.api.nvim_set_hl(0, 'NormalFloat', { bg = float_bg, fg = fg })
  vim.api.nvim_set_hl(0, 'FloatBorder', { bg = float_bg, fg = border_color })
  vim.api.nvim_set_hl(0, 'FloatTitle', { bg = float_bg, fg = accent_primary, bold = true })

  -- 3. Telescope Picker
  vim.api.nvim_set_hl(0, 'TelescopeNormal', { bg = bg, fg = fg })
  vim.api.nvim_set_hl(0, 'TelescopeBorder', { bg = bg, fg = border_color })
  vim.api.nvim_set_hl(0, 'TelescopePromptNormal', { bg = bg, fg = fg })
  vim.api.nvim_set_hl(0, 'TelescopePromptBorder', { bg = bg, fg = border_color })
  vim.api.nvim_set_hl(0, 'TelescopePromptPrefix', { bg = bg, fg = accent_primary })
  vim.api.nvim_set_hl(0, 'TelescopePromptTitle', { bg = accent_primary, fg = bg, bold = true })
  vim.api.nvim_set_hl(0, 'TelescopeResultsTitle', { bg = bg, fg = border_color })
  vim.api.nvim_set_hl(0, 'TelescopePreviewTitle', { bg = sel_bg, fg = sel_fg, bold = true })
  vim.api.nvim_set_hl(0, 'TelescopeSelection', { bg = sel_bg, fg = sel_fg, bold = true })
  vim.api.nvim_set_hl(0, 'TelescopeMatching', { fg = accent_search, bold = true })

  -- 4. snacks.nvim / fzf-lua Pickers
  vim.api.nvim_set_hl(0, 'SnacksPicker', { bg = bg, fg = fg })
  vim.api.nvim_set_hl(0, 'SnacksPickerBorder', { bg = bg, fg = border_color })
  vim.api.nvim_set_hl(0, 'SnacksPickerListCursorLine', { bg = sel_bg, fg = accent_primary, bold = true })
  vim.api.nvim_set_hl(0, 'SnacksPickerPreviewCursorLine', { bg = sel_bg })
  vim.api.nvim_set_hl(0, 'SnacksPickerSelected', { bg = sel_bg, fg = accent_secondary, bold = true })
  vim.api.nvim_set_hl(0, 'FzfLuaNormal', { bg = bg, fg = fg })
  vim.api.nvim_set_hl(0, 'FzfLuaBorder', { bg = bg, fg = border_color })

  -- 5. Popup Completion Menu
  vim.api.nvim_set_hl(0, 'Pmenu', { bg = bg, fg = fg })
  vim.api.nvim_set_hl(0, 'PmenuSel', { bg = sel_bg, fg = sel_fg, bold = true })
  vim.api.nvim_set_hl(0, 'PmenuSbar', { bg = bg })
  vim.api.nvim_set_hl(0, 'PmenuThumb', { bg = border_color })

  -- 6. Window Separators & Search
  vim.api.nvim_set_hl(0, 'WinSeparator', { fg = border_color, bg = 'NONE' })
  vim.api.nvim_set_hl(0, 'CurSearch', { bg = accent_primary, fg = bg, bold = true })
  vim.api.nvim_set_hl(0, 'Search', { bg = sel_bg, fg = sel_fg })
  vim.api.nvim_set_hl(0, 'IncSearch', { bg = accent_secondary, fg = bg, bold = true })

  -- Apply UI theme (Dropbar, Tabline, Bufferline)
  M.apply_ui_theme(colors)

  -- Invoke custom reload callbacks
  for _, cb in ipairs(callbacks) do
    pcall(cb, colors)
  end

  -- Emit User autocmd for any other listeners
  vim.api.nvim_exec_autocmds('User', { pattern = 'NoctaliaReload' })
end

--- Clear Noctalia overrides so colorscheme can express native styling
function M.apply_standard()
  local groups = {
    'NormalFloat',
    'FloatBorder',
    'FloatTitle',
    'TelescopeNormal',
    'TelescopeBorder',
    'TelescopePromptNormal',
    'TelescopePromptBorder',
    'TelescopePromptPrefix',
    'TelescopePromptTitle',
    'TelescopeResultsTitle',
    'TelescopePreviewTitle',
    'TelescopeSelection',
    'TelescopeMatching',
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
  }
  for _, g in ipairs(groups) do
    vim.api.nvim_set_hl(0, g, {})
  end

  -- Refined, distinct selection and active cursor highlights for Standard profile
  local sc = get_standard_colors()
  if sc.is_light then
    vim.api.nvim_set_hl(0, 'Visual', { bg = '#cfe0f7', fg = '#181b1b' })
    vim.api.nvim_set_hl(0, 'VisualNOS', { bg = '#cfe0f7', fg = '#181b1b' })
    vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#eee6dd' })
    vim.api.nvim_set_hl(0, 'SnacksPickerListCursorLine', { bg = '#dce6f8', fg = '#1e50ba', bold = true })
    vim.api.nvim_set_hl(0, 'SnacksPickerPreviewCursorLine', { bg = '#e7ded3' })
    vim.api.nvim_set_hl(0, 'SnacksPickerSelected', { bg = '#b8d0f7', fg = '#1e50ba', bold = true })
  else
    vim.api.nvim_set_hl(0, 'Visual', { bg = '#3e4451' })
    vim.api.nvim_set_hl(0, 'VisualNOS', { bg = '#3e4451' })
    vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#2c313a' })
    vim.api.nvim_set_hl(0, 'SnacksPickerListCursorLine', { bg = '#3e4451', fg = '#61afef', bold = true })
    vim.api.nvim_set_hl(0, 'SnacksPickerPreviewCursorLine', { bg = '#2c313a' })
    vim.api.nvim_set_hl(0, 'SnacksPickerSelected', { bg = '#3b4252', fg = '#61afef', bold = true })
  end

  M.apply_ui_theme()
end

local watcher_handle = nil

function M.start_watcher()
  if watcher_handle then return end
  local uv = vim.uv or vim.loop
  local watch_dir = vim.fs.dirname(M.THEME_PATH)
  local target_file = vim.fs.basename(M.THEME_PATH)

  watcher_handle = uv.new_fs_event()
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

--- Set active theme profile
---@param profile 'noctalia'|'standard'
---@param opts? { silent?: boolean, init?: boolean }
function M.set_profile(profile, opts)
  opts = opts or {}
  if profile == 'noctalia' then
    M.config.profile = 'noctalia'
    -- Only noctalia profile hardcodes its theme (lazy-loads nightfox and dayfox with transparency)
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

    -- Standard profile follows the original theme set in themes.lua
    local target_theme = M.config.standard_colorscheme or M.original_colorscheme or detect_themes_colorscheme()

    -- Reset nightfox transparency if standard theme happens to be nightfox
    if target_theme == 'dayfox' or (target_theme and target_theme:match 'fox') then
      pcall(function()
        require('nightfox').setup { options = { transparent = false } }
      end)
    end

    -- Re-apply original colorscheme if switching back from noctalia or if not already active
    if target_theme and (not opts.init or vim.g.colors_name ~= target_theme) then
      pcall(vim.cmd.colorscheme, target_theme)
    end

    M.apply_standard()
    if not opts.silent then
      vim.notify('Theme Profile: Standard (' .. (target_theme or vim.g.colors_name or 'default') .. ')', vim.log.levels.INFO)
    end
  end
end

--- Toggle between Noctalia and Standard profiles
function M.toggle_profile()
  if M.config.profile == 'noctalia' then
    M.set_profile 'standard'
  else
    M.set_profile 'noctalia'
  end
end

--- Setup theme profiles and watchers
---@param opts? table
function M.setup(opts)
  if opts then M.config = vim.tbl_deep_extend('force', M.config, opts) end

  if not M.original_colorscheme or M.original_colorscheme == '' or M.original_colorscheme == 'default' then
    M.original_colorscheme = detect_themes_colorscheme()
  end

  if M.config.profile == 'noctalia' then
    M.set_profile('noctalia', { silent = true, init = true })
  else
    M.set_profile('standard', { silent = true, init = true })
  end

  vim.api.nvim_create_autocmd('FocusGained', {
    callback = function()
      if M.config.profile == 'noctalia' then M.apply() end
    end,
  })

  vim.api.nvim_create_autocmd('ColorScheme', {
    callback = function()
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
