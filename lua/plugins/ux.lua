local function gh(repo) return 'https://github.com/' .. repo end

-- 1. Plugin Declarations (batched)
vim.pack.add {
  gh 'NMAC427/guess-indent.nvim',
  { src = 'https://codeberg.org/cryptomilk/nvim-pack-ui' },
  gh 'Bekaboo/dropbar.nvim',
  gh 'mikavilpas/yazi.nvim',
  gh 'folke/persistence.nvim',
  gh 'nvim-mini/mini.nvim',
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

-- 4. Mini.nvim suite
if vim.g.have_nerd_font then
  require('mini.icons').setup()
  MiniIcons.mock_nvim_web_devicons()
end

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
  get_symbols = function(self, buf, win, cursor)
    if type(self) == 'number' then buf = self end

    local bufname = vim.api.nvim_buf_get_name(buf)
    if bufname == '' or vim.bo[buf].buftype ~= '' then return {} end

    -- Detect project root markers; fallback to cwd if none found
    local root_markers = { '.git', 'package.json', 'Cargo.toml', 'pyproject.toml', 'go.mod', 'Makefile' }
    local root = (vim.fs and vim.fs.root and vim.fs.root(buf, root_markers)) or vim.fn.getcwd()

    local norm_buf = vim.fs.normalize(bufname)
    local norm_root = vim.fs.normalize(root)
    if norm_root:sub(-1) == '/' and #norm_root > 1 then norm_root = norm_root:sub(1, -2) end

    local root_name = vim.fs.basename(norm_root)
    if root_name == '' then root_name = norm_root end

    -- Determine path relative to root
    local rel_path = ''
    if vim.startswith(norm_buf, norm_root .. '/') then
      rel_path = norm_buf:sub(#norm_root + 2)
    else
      rel_path = vim.fn.fnamemodify(norm_buf, ':t')
    end

    -- Format as "ProjectRoot/.../file" if deeper than 1 subfolder
    local parts = vim.split(rel_path, '/')
    local path_display
    if #parts > 2 then
      path_display = string.format('%s/.../%s', root_name, parts[#parts])
    elseif #parts == 2 then
      path_display = string.format('%s/%s/%s', root_name, parts[1], parts[2])
    else
      path_display = string.format('%s/%s', root_name, parts[1])
    end

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

-- 6. Bufferline

-- Neovim's tabline container falls back to TabLineFill / TabLine whenever a highlight group has bg = 'none'.
-- Themes (like Dayfox/Nightfox) define an opaque background for TabLineFill, which blocks transparency.
local function set_bufferline_transparency()
  vim.api.nvim_set_hl(0, 'TabLineFill', { bg = 'none' })
  vim.api.nvim_set_hl(0, 'TabLine', { bg = 'none' })
end
set_bufferline_transparency()
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = set_bufferline_transparency,
})

local bufferline = require 'bufferline'
bufferline.setup {
  highlights = {
    fill = { bg = 'none' },
    background = { bg = 'none' },

    -- Visible buffers (inactive splits)
    buffer_visible = { bg = 'none' },

    -- Selected buffer (active)
    buffer_selected = {
      bg = 'none',
      bold = true,
      italic = false,
    },

    -- Separators & UI components
    separator = { bg = 'none' },
    separator_visible = { bg = 'none' },
    separator_selected = { bg = 'none' },
    close_button = { bg = 'none' },
    close_button_visible = { bg = 'none' },
    close_button_selected = { bg = 'none' },
    tab = { bg = 'none' },
    tab_selected = { bg = 'none' },
    tab_close = { bg = 'none' },
    indicator_selected = { bg = 'none' },
    indicator_visible = { bg = 'none' },
    modified = { bg = 'none' },
    modified_visible = { bg = 'none' },
    modified_selected = { bg = 'none' },
    duplicate = { bg = 'none' },
    duplicate_visible = { bg = 'none' },
    duplicate_selected = { bg = 'none' },
    trunc_marker = { bg = 'none' },
    offset_separator = { bg = 'none' },
  },
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

    -- offsets = {
    --     {
    --         filetype = "NvimTree",
    --         text = "File Explorer" | function ,
    --         text_align = "left" | "center" | "right"
    --         separator = true
    --     }
    -- },

    color_icons = true, -- whether or not to add the filetype icon highlights
    show_buffer_icons = true,
    show_buffer_close_icons = false,
    show_close_icon = true,
    show_tab_indicators = true,
    -- can also be a table containing 2 custom separators
    -- [focused and unfocused]. eg: { '|', '|' }
    -- separator_style = 'slant' | 'slope' | 'thick' | 'thin' | { 'any', 'any' },
  },
}
