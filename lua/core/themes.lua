---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add { gh 'catppuccin/nvim' }
vim.pack.add { gh 'EdenEast/nightfox.nvim' }
vim.pack.add { gh 'projekt0n/github-nvim-theme' }
vim.pack.add { gh 'rose-pine/neovim' }
vim.pack.add { gh 'sainnhe/everforest' }
vim.pack.add { gh 'folke/tokyonight.nvim' }

-- require("catppuccin").setup({
-- 	flavour = "latte",
-- 	transparent_background = true,
-- })
-- require("github-theme").setup({
-- 	options = {
-- 		transparent = true,
-- 	}
-- })
require('nightfox').setup {
  options = {
    transparent = true,
  },
}
-- require("rose-pine").setup({
-- 	variant = "dawn",
-- 	styles = { transparency = true},
-- })
require('tokyonight').setup {
  transparent = true,
  styles = {
    comments = { italic = false }, -- Disable italics in comments
  },
}
--
vim.g.everforest_transparent_background = 1
vim.cmd.colorscheme 'dayfox'

-- Force keywords and types to italic
vim.api.nvim_set_hl(0, '@keyword', { italic = true })
vim.api.nvim_set_hl(0, '@keyword.function', { italic = true })
vim.api.nvim_set_hl(0, '@type.builtin', { italic = true })
-- vim.api.nvim_set_hl(0, "@comment", { italic = true })

local M = {}

local THEME_PATH = vim.fn.expand '~/.config/ghostty/themes/noctalia'

local function parse_ghostty_theme(path)
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

-- Apply highlight groups
function M.apply()
  local theme = parse_ghostty_theme(THEME_PATH)
  if not theme then return end

  -- Extract Ghostty theme values with fallbacks to your palette
  local bg = theme['background'] or '#d3dff8'
  local fg = theme['foreground'] or '#18191b'
  local sel_bg = theme['selection-background'] or theme.palette[0] or '#9eb8ef'
  local sel_fg = theme['selection-foreground'] or theme['cursor-text'] or '#47494f'
  local border_color = theme.palette[8] or '#6f7fa1'
  local accent_primary = theme.palette[2] or '#1e50ba'
  local accent_secondary = theme.palette[4] or '#70199a'
  local accent_search = theme.palette[1] or '#c6003d'

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
end

-- Watch directory using libuv fs_event
function M.setup()
  M.apply()

  local uv = vim.uv or vim.loop
  local watch_dir = vim.fs.dirname(THEME_PATH)
  local target_file = vim.fs.basename(THEME_PATH)

  local handle = uv.new_fs_event()
  handle:start(watch_dir, {}, function(err, filename, _)
    if err then return end
    if filename == target_file or not filename then vim.schedule(function() M.apply() end) end
  end)

  vim.api.nvim_create_autocmd('FocusGained', {
    callback = function() M.apply() end,
  })
end

M.setup()

return M
