local icons = require 'icons'
local util = require 'core.util'

local M = {}

local gh = util.gh

-- ============================================================================
-- 1. PLUGIN DECLARATIONS (Batched)
-- ============================================================================

vim.pack.add {
  gh 'folke/snacks.nvim',
  gh 'folke/which-key.nvim',
  gh 'NMAC427/guess-indent.nvim',
  { src = 'https://codeberg.org/cryptomilk/nvim-pack-ui' },
  gh 'Bekaboo/dropbar.nvim',
  gh 'mikavilpas/yazi.nvim',
  gh 'nvim-mini/mini.nvim',
  gh 'Mirsmog/real-icons.nvim',
  gh 'folke/todo-comments.nvim',
  gh 'rachartier/tiny-cmdline.nvim',
  gh 'folke/flash.nvim',
  gh 'nvim-pack/nvim-spectre',
  gh 'serhez/bento.nvim',
  gh 'nemanjamalesija/smart-paste.nvim',
  gh 'rachartier/tiny-glimmer.nvim',
}

-- ============================================================================
-- 2. SNACKS.NVIM & WHICH-KEY
-- ============================================================================

require('snacks').setup {
  animate = { enabled = false },
  bigfile = { enabled = true },
  dashboard = {
    enabled = not util.in_leetcode(),
    preset = {
      keys = {
        { icon = ' ', key = 'p', desc = 'Projects', action = ':lua require("mini.pick").registry.projects()' },
        { icon = ' ', key = 'r', desc = 'Recent Files', action = ':lua require("mini.extra").pickers.oldfiles()' },
        { icon = ' ', key = 'f', desc = 'Find File', action = ':lua require("mini.pick").builtin.files()' },
        { icon = ' ', key = 'g', desc = 'Live Grep', action = ':lua require("mini.pick").builtin.grep_live()' },
        { icon = ' ', key = 'c', desc = 'Config', action = ":lua require('mini.pick').builtin.files({}, { source = { cwd = vim.fn.stdpath('config') } })" },
        { icon = ' ', key = 't', desc = 'TODOs & Bugs', action = ':lua require("mini.pick").registry.todo()' },
        { icon = ' ', key = 'T', desc = 'Task & Bug Board', action = ':TaskBoard' },
        { icon = ' ', key = 'N', desc = 'New Task / Bug', action = ':TaskNew' },
        { icon = '󰠮 ', key = 'n', desc = 'Project Scratchpad', action = ':lua Snacks.scratch()' },
        { icon = ' ', key = 's', desc = 'Restore Session', section = 'session' },
        { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
      },
    },
    sections = {
      { section = 'keys', gap = 1, padding = 1 },
      {
        pane = 2,
        icon = ' ',
        title = 'Projects',
        section = 'projects',
        indent = 2,
        padding = 1,
        dirs = util.list_projects,
      },
      {
        pane = 2,
        icon = ' ',
        title = 'Git Status',
        section = 'terminal',
        enabled = function() return Snacks.git.get_root() ~= nil end,
        cmd = vim.fn.stdpath 'config' .. '/lua/assets/git_status.sh',
        height = 7,
        padding = 1,
        ttl = 5 * 60,
        indent = 3,
      },
      {
        pane = 2,
        icon = ' ',
        title = 'Tasks & Bugs',
        section = 'terminal',
        cmd = (vim.fn.executable 'tsk' == 1 and 'tsk' or (vim.fn.stdpath 'config' .. '/tools/tsk/tsk')) .. ' dashboard',
        height = 7,
        padding = 1,
        ttl = 60,
        indent = 3,
      },
    },
  },
  explorer = { enabled = false },
  gh = { enabled = false },
  indent = { enabled = false },
  input = { enabled = true },
  picker = { enabled = false },
  notifier = { enabled = true },
  quickfile = { enabled = true },
  scope = { enabled = false },
  scratch = { enabled = true },
  scroll = { enabled = false },
  statuscolumn = { enabled = true },
  terminal = {
    enabled = true,
    win = {
      position = 'bottom',
      height = 0.35,
    },
  },
  words = { enabled = true },
  zen = { enabled = true },
}

pcall(function()
  require('which-key').setup {
    preset = 'modern',
    delay = function(ctx) return ctx.plugin and 0 or 200 end,
    icons = { mappings = vim.g.have_nerd_font },
    win = { no_overlap = false },
  }
end)

-- ============================================================================
-- 3. ICONS, NAVIGATION & MINI.NVIM CORE
-- ============================================================================

pcall(function()
  local mini_icons = require 'mini.icons'
  mini_icons.setup()
  mini_icons.mock_nvim_web_devicons()
end)

local latte_pack = {
  type = 'vscode',
  path = vim.fn.stdpath 'config' .. '/lua/assets/catppuccin-latte',
  manifest = 'theme.json',
}

pcall(function()
  require('real-icons').setup {
    pack = 'catppuccin-latte',
    integrations = {
      mini_files = true,
    },
    packs = {
      ['catppuccin-latte'] = latte_pack,
      latte = latte_pack,
    },
  }
end)

pcall(function() require('mini.bufremove').setup() end)
pcall(function() require('mini.sessions').setup() end)

require('yazi').setup { open_for_directories = true }
require('flash').setup()

vim.api.nvim_create_user_command('Spectre', function() require('spectre').open() end, { desc = 'Open Spectre search & replace' })

local mini_files_ready = false

--- Lazily initialize and toggle mini.files at the current file or cwd.
function M.toggle_files()
  if not mini_files_ready then
    mini_files_ready = true
    require('mini.files').setup {
      content = {
        prefix = function(fs_entry)
          local cat = fs_entry.fs_type == 'directory' and 'directory' or 'file'
          local icon, hl = icons.file_icon(cat, fs_entry.name)
          return icon .. ' ', hl or (cat == 'directory' and 'MiniFilesDirectory' or 'MiniFilesFile')
        end,
      },
      windows = {
        preview = true,
        width_focus = 35,
        width_preview = 45,
      },
    }
  end

  local mf = require 'mini.files'
  if not mf.close() then
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname ~= '' and vim.uv.fs_stat(bufname) then
      mf.open(bufname, true)
    else
      mf.open(vim.fn.getcwd(), true)
    end
  end
end

-- ============================================================================
-- 4. BUFFER-LAZY EDITING PLUGINS
-- ============================================================================

local disabled_indentscope_fts = {
  help = true,
  man = true,
  checkhealth = true,
  lspinfo = true,
  snacks_dashboard = true,
  snacks_notif = true,
  snacks_terminal = true,
  minifiles = true,
  minipick = true,
  overseer = true,
  tasks_board = true,
  tasks_report = true,
  Trouble = true,
  ['dap-view'] = true,
  ['dap-repl'] = true,
  bigfile = true,
}

vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter' }, {
  group = util.augroup 'mini_indentscope_disable',
  callback = function(args)
    if not vim.api.nvim_buf_is_valid(args.buf) then return end
    if vim.bo[args.buf].buftype ~= '' or disabled_indentscope_fts[vim.bo[args.buf].filetype] then vim.b[args.buf].miniindentscope_disable = true end
  end,
})

local buf_plugins_ready = false

local function setup_buffer_plugins()
  if buf_plugins_ready then return end
  buf_plugins_ready = true

  pcall(function() require('guess-indent').setup {} end)
  pcall(function() require('todo-comments').setup { signs = false } end)
  pcall(function()
    local indentscope = require 'mini.indentscope'
    indentscope.setup {
      symbol = '│',
      draw = {
        delay = 50,
        animation = indentscope.gen_animation.none(),
        priority = 2,
      },
      mappings = {
        object_scope = '',
        object_scope_with_border = '',
        goto_top = '[i',
        goto_bottom = ']i',
      },
      options = {
        border = 'both',
        indent_at_cursor = false,
        try_as_border = true,
        n_lines = 1000,
      },
    }
    if not vim.b.miniindentscope_disable and type(indentscope.draw) == 'function' then pcall(indentscope.draw) end
  end)
  pcall(function()
    require('mini.ai').setup {
      mappings = { around_next = 'aa', inside_next = 'ii' },
      n_lines = 500,
    }
  end)
  pcall(function()
    require('mini.surround').setup {
      mappings = {
        add = 'gsa',
        delete = 'gsd',
        find = 'gsf',
        find_left = 'gsF',
        highlight = 'gsh',
        replace = 'gsr',
        suffix_last = 'l',
        suffix_next = 'n',
      },
      custom_surroundings = {
        ['$'] = {
          input = { '%$().-()%$' },
          output = { left = '$', right = '$' },
          desc = 'Inline math ($...$)',
        },
      },
    }
    pcall(function() require('plugins.mini_surround_wk').setup() end)
  end)
  pcall(function() require('mini.pairs').setup() end)

  pcall(function()
    require('tiny-glimmer').setup {
      enabled = true,
      disable_warnings = true,
      autoreload = true,
      default_animation = 'fade',
      overwrite = {
        auto_map = true,
        yank = { enabled = true, default_animation = 'fade' },
        paste = { enabled = false },
      },
    }
  end)

  pcall(function()
    require('smart-paste').setup { exclude_filetypes = {} }

    for _, key in ipairs { 'p', 'P', 'gp', 'gP', ']p', '[p' } do
      local mapped = vim.fn.maparg(key, 'n', false, true)
      if mapped and mapped.callback then
        local orig_cb = mapped.callback
        vim.keymap.set('n', key, function()
          pcall(function() require('tiny-glimmer.overwrite.paste').paste { default_animation = 'fade' } end)
          return orig_cb()
        end, { expr = true, desc = mapped.desc })
      end
    end
  end)
end

vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
  group = util.augroup 'ux_buffer_plugins',
  once = true,
  callback = setup_buffer_plugins,
})

-- ============================================================================
-- 5. COMMAND LINE, BREADCRUMBS & BUFFER MANAGER
-- ============================================================================

local ok_tiny, tiny_cmdline = pcall(require, 'tiny-cmdline')
if ok_tiny then
  tiny_cmdline.setup {
    on_reposition = tiny_cmdline.adapters.blink,
    native_types = { '/', '?' },
  }
end

local dropbar = require 'dropbar'
local sources = require 'dropbar.sources'
local db_utils = require 'dropbar.utils'
local dropbar_configs = require 'dropbar.configs'

dropbar.setup {
  bar = {
    truncate = true,
    sources = function(buf, _)
      if vim.bo[buf].ft == 'markdown' then return { sources.markdown } end
      if vim.bo[buf].buftype == 'terminal' then return { sources.terminal } end
      return {
        db_utils.source.fallback {
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
    lsp = {
      max_depth = 2,
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
      max_depth = 2,
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

-- Align breadcrumbs after the window gutter (line numbers / sign column)
setmetatable(dropbar_configs.opts.bar.padding, {
  __index = function(_, k)
    if k == 'left' then
      local win = vim.g.statusline_winid
      if not win or win == 0 then win = vim.api.nvim_get_current_win() end
      local wininfo = vim.fn.getwininfo(win)[1]
      return wininfo and wininfo.textoff or 0
    end
  end,
})
dropbar_configs.opts.bar.padding.left = nil

pcall(function()
  local bento = require 'bento'
  bento.setup {
    ordering_metric = 'access',
    ui = {
      mode = 'floating',
      floating = {
        position = 'middle-right',
        minimal_menu = 'dashed',
        dash_char = '─',
        border = 'rounded',
      },
    },
    highlights = {
      window_bg = 'BentoNormal',
    },
  }

  local ok_api, bento_api = pcall(require, 'bento.api')
  if ok_api then
    bento_api.register_expand_key ';'
    bento_api.register_last_buffer_key ';'
    bento_api.register_collapse_key '<Esc>'
    bento_api.register_prev_page_key '['
    bento_api.register_next_page_key ']'

    bento_api.register_action('open', { key = '<CR>', action = bento_api.actions.open, hl = 'DiagnosticVirtualTextHint' })
    bento_api.register_action('delete', { key = '<BS>', action = bento_api.actions.delete, hl = 'DiagnosticVirtualTextError' })
    bento_api.register_action('vsplit', { key = '|', action = bento_api.actions.vsplit, hl = 'DiagnosticVirtualTextInfo' })
    bento_api.register_action('split', { key = '_', action = bento_api.actions.split, hl = 'DiagnosticVirtualTextInfo' })
    bento_api.register_action('lock', { key = '*', action = bento_api.actions.lock, hl = 'DiagnosticVirtualTextWarn' })
    bento_api.set_default_action 'open'
  end
end)

return M
