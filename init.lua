vim.loader.enable()

---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

vim.o.autoread = true

-- Trigger autoread when the file changes outside or when switching buffers
vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'CursorHoldI', 'FocusGained' }, {
  callback = function()
    if vim.fn.mode() ~= 'c' then vim.cmd 'checktime' end
  end,
})

vim.pack.add { gh 'folke/snacks.nvim' }

require('snacks').setup {
  animate = { enabled = false },
  bigfile = { enabled = true },
  dashboard = {
    enabled = true,
    sections = {
      { section = 'keys', gap = 1, padding = 1 },
      { pane = 2, icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 },
      { pane = 2, icon = ' ', title = 'Projects', section = 'projects', indent = 2, padding = 1 },
      {
        pane = 2,
        icon = ' ',
        title = 'Git Status',
        section = 'terminal',
        enabled = function() return Snacks.git.get_root() ~= nil end,
        cmd = 'git status --short --branch --renames',
        height = 5,
        padding = 1,
        ttl = 5 * 60,
        indent = 3,
      },
    },
  },
  explorer = { enabled = false },
  indent = { enabled = false },
  input = { enabled = true },
  picker = { enabled = true, ui_select = true },
  notifier = { enabled = true },
  quickfile = { enabled = true },
  scope = { enabled = true },
  scroll = { enabled = false },
  statuscolumn = { enabled = false },
  words = { enabled = true },
}
require 'core.options'
require 'core.themes'
require 'core.autocmd'
require 'plugins.telescope'
require 'plugins.code'
require 'core.keymaps'
require 'plugins.init'
require 'plugins.ux'
require 'plugins.statusline'

local opt_langs = {
  c = 'cpp',
  cpp = 'cpp',
  python = 'python',
  quarto = 'python',
  rust = 'rust',
  java = 'java',
  typst = 'typst',
  tex = 'latex',
  bib = 'latex',
  markdown = 'markdown',
  php = 'php',
}

vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    local module_name = opt_langs[args.match]
    if module_name then pcall(require, 'plugins.opt.' .. module_name) end
  end,
})
