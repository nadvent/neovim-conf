local function gh(repo) return 'https://github.com/' .. repo end

-- 1. Plugin Declarations (batched)
vim.pack.add {
  gh 'NMAC427/guess-indent.nvim',
  { src = 'https://codeberg.org/cryptomilk/nvim-pack-ui' },
  gh 'Bekaboo/dropbar.nvim',
  gh 'mikavilpas/yazi.nvim',
  gh 'folke/persistence.nvim',
  gh 'nvim-mini/mini.nvim',
  gh 'Mirsmog/real-icons.nvim',
  gh 'folke/todo-comments.nvim',
  gh 'folke/noice.nvim',
  gh 'folke/trouble.nvim',
  gh 'folke/flash.nvim',
  gh 'saghen/blink.indent',
  gh 'MunifTanjim/nui.nvim',
  gh 'nvim-pack/nvim-spectre',
  gh 'akinsho/bufferline.nvim',
}

-- 2. Fast / Zero-Config Setups
require('guess-indent').setup {}
require('todo-comments').setup { signs = false }
require('yazi').setup { open_for_directories = true }
require('blink.indent').setup {}
require('flash').setup()

-- 2.5 Lazy-loading

vim.api.nvim_create_user_command('Spectre', function() require('spectre').open() end, {})
vim.schedule(function() require('trouble').setup {} end)

-- 3. Session Management (persistence + colocated autocmd)
require('persistence').setup()
vim.api.nvim_create_autocmd('VimEnter', {
  group = vim.api.nvim_create_augroup('persistence', { clear = true }),
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 then require('persistence').load() end
  end,
})

-- 4. Icon provider & Mini.nvim suite
local latte_pack = {
  type = 'vscode',
  path = vim.fn.stdpath 'config' .. '/lua/assets/catppuccin-latte',
  manifest = 'theme.json',
}

require('real-icons').setup {
  integrations = {
    snacks_picker = true,
    bufferline = true,
  },
  pack = 'catppuccin-latte',
  packs = {
    ['catppuccin-latte'] = latte_pack,
    latte = latte_pack,
  },
}

require('mini.ai').setup {
  mappings = { around_next = 'aa', inside_next = 'ii' },
  n_lines = 500,
}
require('mini.surround').setup()
require('mini.pairs').setup()

-- 5. Command line & UI enhancements
require('noice').setup {
  notify = { enabled = false },
  lsp = {
    override = {
      ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
      ['vim.lsp.util.stylize_markdown'] = true,
    },
  },
  presets = {
    bottom_search = true,
    command_palette = true,
    long_message_to_split = true,
    inc_rename = false,
    lsp_doc_border = false,
  },
}

-- 5. Minimalistic Breadcrumbs

local dropbar = require 'dropbar'
local sources = require 'dropbar.sources'
local utils = require 'dropbar.utils'
local bar = require 'dropbar.bar'

-- 2. Custom single-symbol path source
local project_path_source = {
  get_symbols = function(self, buf)
    buf = type(self) == 'number' and self or buf

    local bufname = vim.api.nvim_buf_get_name(buf)
    if bufname == '' or vim.bo[buf].buftype ~= '' then return {} end

    -- Detect project root markers; fallback to cwd if none found
    local root_markers = { '.git', 'package.json', 'Cargo.toml', 'pyproject.toml', 'go.mod', 'Makefile' }
    local root = (vim.fs and vim.fs.root and vim.fs.root(buf, root_markers)) or vim.fn.getcwd()
    local norm_root = vim.fs.normalize(root):gsub('/+$', '')
    local root_name = vim.fs.basename(norm_root)
    if root_name == '' then root_name = norm_root end

    -- Determine path relative to root
    local norm_buf = vim.fs.normalize(bufname)
    local rel_path = vim.startswith(norm_buf, norm_root .. '/') and norm_buf:sub(#norm_root + 2) or vim.fs.basename(norm_buf)

    -- Format as "ProjectRoot/.../file" if deeper than 1 subfolder, else "ProjectRoot/path"
    local parts = vim.split(rel_path, '/')
    local path_display = #parts > 2 and string.format('%s/.../%s', root_name, parts[#parts]) or string.format('%s/%s', root_name, rel_path)

    return {
      bar.dropbar_symbol_t:new {
        name = path_display,
        name_hl = 'DropBarFileName',
      },
    }
  end,
}

-- 3. Register the custom source in dropbar.setup

dropbar.setup {
  bar = {
    truncate = true,
    sources = function(buf, win)
      if vim.bo[buf].ft == 'markdown' then return {
        project_path_source,
        sources.markdown,
      } end
      if vim.bo[buf].buftype == 'terminal' then return {
        sources.terminal,
      } end
      return {
        project_path_source,
        utils.source.fallback {
          sources.lsp,
          sources.treesitter,
        },
      }
    end,
  },
  menu = {
    win_configs = {
      border = 'rounded',
    },
  },

  sources = {
    path = {
      max_depth = 2,
      -- Set to project root rather than global cwd if preferred
      relative_to = function() return vim.fn.getcwd() end,
    },
    lsp = {
      -- Cap symbol nesting to prevent endless chains
      max_depth = 2,
      -- Whitelist only structural code symbols (hides local vars, keys, properties)
      valid_symbols = {
        'File',
        'Module',
        'Namespace',
        'Package',
        'Class',
        'Method',
        'Constructor',
        'Enum',
        'Interface',
        'Function',
        'Struct',
      },
    },
    treesitter = {
      -- Cap nesting when falling back to Tree-sitter
      max_depth = 2,
      -- Strip out if/for/while/call/block statements
      valid_types = {
        'class',
        'constructor',
        'enum',
        'function',
        'interface',
        'method',
        'module',
        'namespace',
        'package',
        'struct',
      },
    },
  },
}

-- 6. Bufferline & Dropbar Theming

local noctalia = require 'core.noctalia'

local function get_contrast_fg(hex, dark_fg, light_fg)
  dark_fg = dark_fg or '#181b1b'
  light_fg = light_fg or '#ffffff'
  local r, g, b = (hex or ''):match '^#(%x%x)(%x%x)(%x%x)$'
  if not r then return light_fg end
  local lum = (0.299 * tonumber(r, 16) + 0.587 * tonumber(g, 16) + 0.114 * tonumber(b, 16)) / 255
  return lum > 0.55 and dark_fg or light_fg
end

local function apply_dropbar_highlights(c)
  local border = c.border_color or '#6f7fa1'
  local fg = c.fg or '#181b1b'
  local accent = c.accent_primary or '#1e50ba'
  local bg = c.bg or '#d3dff8'

  local hls = {
    WinBar = { bg = 'none', underline = true, sp = border },
    WinBarNC = { bg = 'none', underline = true, sp = border },
    DropBarFileName = { fg = fg, bold = true, underline = true, sp = border },
    DropBarIconUISeparator = { fg = border, underline = true, sp = border },
    DropBarIconUISeparatorNC = { fg = border, underline = true, sp = border },
    DropBarCurrentContext = { fg = accent, bold = true, underline = true, sp = border },
    DropBarCurrentContextIcon = { fg = accent, underline = true, sp = border },
    DropBarCurrentContextName = { fg = accent, bold = true, underline = true, sp = border },
    DropBarMenuFloatBorder = { fg = border, bg = bg },
    DropBarMenuNormalFloat = { fg = fg, bg = bg },
  }
  for group, def in pairs(hls) do
    vim.api.nvim_set_hl(0, group, def)
  end
end

local function get_bufferline_highlights(c)
  c = c or noctalia.get_colors()
  local sep = c.border_color or '#6f7fa1'
  local accent = c.accent_primary or '#1e50ba'
  local search_accent = c.accent_search or '#c6003d'
  local active_fg = get_contrast_fg(accent, c.fg or '#181b1b', c.bg or '#ffffff')
  local palette = c.palette or {}

  local function hl(opts) return vim.tbl_extend('keep', opts or {}, { bg = 'none', underline = true, sp = sep }) end

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

    -- Duplicate buffer paths
    duplicate = hl { fg = c.sel_fg or '#47494f', italic = true },
    duplicate_visible = hl { fg = c.sel_fg or '#47494f', italic = true },
    duplicate_selected = hl { fg = active_fg, bg = accent, sp = accent, italic = true },

    -- Modified buffers
    modified = modified,
    modified_visible = modified,
    tab_close = modified,

    -- Diagnostics (inactive / visible)
    error = modified,
    error_visible = modified,
    warning = hl { fg = palette[3] or '#e5c07b' },
    warning_visible = hl { fg = palette[3] or '#e5c07b' },
    info = hl { fg = palette[6] or '#1b4f7e' },
    info_visible = hl { fg = palette[6] or '#1b4f7e' },
    hint = hl { fg = palette[5] or '#017979' },
    hint_visible = hl { fg = palette[5] or '#017979' },
  }

  -- Batch-assign uniform highlight states
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

local function apply_ui_theme(c)
  c = c or noctalia.get_colors()
  local sep = c.border_color or '#6f7fa1'

  -- Preserve TabLine transparency across colorschemes
  vim.api.nvim_set_hl(0, 'TabLineFill', { bg = 'none', underline = true, sp = sep })
  vim.api.nvim_set_hl(0, 'TabLine', { bg = 'none', underline = true, sp = sep })

  apply_dropbar_highlights(c)

  local ok, bl_hl = pcall(require, 'bufferline.highlights')
  if not ok then return end

  for name, hl_def in pairs(get_bufferline_highlights(c)) do
    local group = bl_hl.generate_name(name)
    if group then vim.api.nvim_set_hl(0, group, hl_def) end
  end
end

apply_ui_theme()
noctalia.on_reload(apply_ui_theme)
vim.api.nvim_create_autocmd('ColorScheme', { callback = function() apply_ui_theme() end })

local bufferline = require 'bufferline'
bufferline.setup {
  highlights = get_bufferline_highlights(),
  options = {
    custom_areas = {
      left = function()
        local win = vim.api.nvim_get_current_win()
        local wininfo = vim.fn.getwininfo(win)[1]
        local gutter_width = wininfo and wininfo.textoff or 0

        if gutter_width > 0 then return { { text = string.rep(' ', gutter_width) } } end
        return {}
      end,
    },
    themable = true, -- allows highlight groups to be overriden i.e. sets highlights as default
    indicator = {
      style = 'underline',
    },
    buffer_close_icon = '󰅖',
    modified_icon = '● ',
    close_icon = ' ',
    left_trunc_marker = ' ',
    right_trunc_marker = ' ',
    separator_style = 'thin',

    color_icons = false, -- whether or not to add the filetype icon highlights
    show_buffer_icons = false,
    show_buffer_close_icons = true,
    show_close_icon = true,
    show_tab_indicators = true,
  },
}
