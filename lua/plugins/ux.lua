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
require('yazi').setup { open_for_directories = true }
require('flash').setup()

local function setup_buffer_plugins()
  if _G._buf_plugins_setup then return end
  _G._buf_plugins_setup = true

  pcall(function() require('guess-indent').setup {} end)
  pcall(function() require('todo-comments').setup { signs = false } end)
  pcall(function() require('blink.indent').setup {} end)
  pcall(function()
    require('mini.ai').setup {
      mappings = { around_next = 'aa', inside_next = 'ii' },
      n_lines = 500,
    }
  end)
  pcall(function() require('mini.surround').setup() end)
  pcall(function() require('mini.pairs').setup() end)
end

vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
  once = true,
  callback = setup_buffer_plugins,
})

-- 2.5 Lazy-loading

vim.api.nvim_create_user_command('Spectre', function() require('spectre').open() end, {})

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
    mini_files = true,
  },
  packs = {
    ['catppuccin-latte'] = latte_pack,
    latte = latte_pack,
  },
}

local function init_mini_files()
  if _G._mini_files_initialized then return end
  _G._mini_files_initialized = true

  require('mini.files').setup {
    content = {
      prefix = function(fs_entry)
        local ok, real_icons = pcall(require, 'real-icons')
        if ok then
          local icon, hl
          if fs_entry.fs_type == 'directory' then
            icon, hl = real_icons.get('folder', fs_entry.name)
            if not icon then
              icon, hl = '', 'MiniFilesDirectory'
            end
          else
            icon, hl = real_icons.get('file', fs_entry.name)
            if not icon then
              icon, hl = '󰈔', 'MiniFilesFile'
            end
          end
          return icon .. ' ', hl
        end
        return require('mini.files').default_prefix(fs_entry)
      end,
    },
    windows = {
      preview = true,
      width_focus = 35,
      width_preview = 45,
    },
  }
end
_G.init_mini_files = init_mini_files

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

    -- Format as "ProjectRoot/.../Folder/file" if exceeding 4 levels, else "ProjectRoot/path"
    local parts = vim.split(rel_path, '/')
    local path_display = #parts >= 4 and string.format('%s/.../%s/%s', root_name, parts[#parts - 1], parts[#parts])
      or string.format('%s/%s', root_name, rel_path)

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

_G.BufferlineToggleMiniFiles = function(minwid, clicks, button, modifiers)
  if button and button ~= 'l' then return end
  vim.schedule(function()
    if _G.init_mini_files then _G.init_mini_files() end
    local ok, mf = pcall(require, 'mini.files')
    if not ok then return end
    if not mf.close() then
      local bufname = vim.api.nvim_buf_get_name(0)
      if bufname ~= '' and vim.uv.fs_stat(bufname) then
        mf.open(bufname, true)
      else
        mf.open(vim.fn.getcwd(), true)
      end
    end
  end)
end

local noctalia = require 'core.noctalia'
noctalia.setup()

local bufferline = require 'bufferline'
bufferline.setup {
  highlights = noctalia.get_bufferline_highlights(),
  options = {
    custom_areas = {
      left = function()
        local win = vim.api.nvim_get_current_win()
        local wininfo = vim.fn.getwininfo(win)[1]
        local gutter_width = wininfo and wininfo.textoff or 0

        local icon = ''
        local icon_w = vim.fn.strdisplaywidth(icon)
        local total_w = math.max(icon_w + 2, gutter_width)
        local remaining = total_w - icon_w
        local pad_left = math.floor(remaining / 2)
        local pad_right = remaining - pad_left

        local dir_hl = vim.api.nvim_get_hl(0, { name = 'Directory', link = false })
        local icon_fg = dir_hl and dir_hl.fg and string.format('#%06x', dir_hl.fg) or '#2848a9'

        local clickable_icon = string.format('%%0@v:lua.BufferlineToggleMiniFiles@%s%s%s%%X', string.rep(' ', pad_left), icon, string.rep(' ', pad_right))

        return {
          {
            text = clickable_icon,
            fg = icon_fg,
            bold = true,
          },
        }
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

    color_icons = true, -- whether or not to add the filetype icon highlights
    show_buffer_icons = false,
    show_buffer_close_icons = true,
    show_close_icon = true,
    show_tab_indicators = true,
  },
}
