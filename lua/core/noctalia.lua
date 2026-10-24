local M = {}

M.THEME_PATH = vim.fn.expand '~/.config/ghostty/themes/noctalia'

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

--- Get resolved Noctalia colors table with palette and sensible fallbacks
---@return table
function M.get_colors()
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

--- Apply core UI highlight groups
function M.apply()
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

  -- 2. General Floating Windows (LSP hover, Mason, Lazy)
  vim.api.nvim_set_hl(0, 'NormalFloat', { bg = bg, fg = fg })
  vim.api.nvim_set_hl(0, 'FloatBorder', { bg = bg, fg = border_color })
  vim.api.nvim_set_hl(0, 'FloatTitle', { bg = bg, fg = accent_primary, bold = true })

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
  vim.api.nvim_set_hl(0, 'SnacksPickerSelected', { bg = sel_bg, fg = sel_fg })
  vim.api.nvim_set_hl(0, 'FzfLuaNormal', { bg = bg, fg = fg })
  vim.api.nvim_set_hl(0, 'FzfLuaBorder', { bg = bg, fg = border_color })

  -- 5. Popup Completion Menu (cmp, blink.cmp, wildmenu)
  vim.api.nvim_set_hl(0, 'Pmenu', { bg = bg, fg = fg })
  vim.api.nvim_set_hl(0, 'PmenuSel', { bg = sel_bg, fg = sel_fg, bold = true })
  vim.api.nvim_set_hl(0, 'PmenuSbar', { bg = bg })
  vim.api.nvim_set_hl(0, 'PmenuThumb', { bg = border_color })

  -- 6. Window Separators & Search
  vim.api.nvim_set_hl(0, 'WinSeparator', { fg = border_color, bg = 'NONE' })
  vim.api.nvim_set_hl(0, 'CurSearch', { bg = accent_primary, fg = bg, bold = true })
  vim.api.nvim_set_hl(0, 'Search', { bg = sel_bg, fg = sel_fg })
  vim.api.nvim_set_hl(0, 'IncSearch', { bg = accent_secondary, fg = bg, bold = true })

  -- Invoke custom reload callbacks
  for _, cb in ipairs(callbacks) do
    pcall(cb, colors)
  end

  -- Emit User autocmd for any other listeners
  vim.api.nvim_exec_autocmds('User', { pattern = 'NoctaliaReload' })
end

local watcher_started = false

--- Setup fs_event watcher and FocusGained autocmd
function M.setup()
  M.apply()

  if watcher_started then return end
  watcher_started = true

  local uv = vim.uv or vim.loop
  local watch_dir = vim.fs.dirname(M.THEME_PATH)
  local target_file = vim.fs.basename(M.THEME_PATH)

  local handle = uv.new_fs_event()
  if handle then
    handle:start(watch_dir, {}, function(err, filename, _)
      if err then return end
      if filename == target_file or not filename then
        vim.schedule(function() M.apply() end)
      end
    end)
  end

  vim.api.nvim_create_autocmd('FocusGained', {
    callback = function() M.apply() end,
  })
end

return M
