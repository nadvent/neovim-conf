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

vim.api.nvim_create_autocmd('BufReadPost', {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
  end,
})

vim.pack.add { gh 'folke/snacks.nvim' }

require('snacks').setup {
  animate = { enabled = false },
  bigfile = { enabled = true },
  dashboard = {
    enabled = true,
    preset = {
      keys = {
        { icon = ' ', key = 'p', desc = 'Projects', action = ':lua Snacks.picker.projects()' },
        { icon = ' ', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
        { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
        { icon = ' ', key = 'g', desc = 'Live Grep', action = ":lua Snacks.dashboard.pick('live_grep')" },
        { icon = ' ', key = 'c', desc = 'Config', action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
        { icon = ' ', key = 't', desc = 'TODOs & Bugs', action = ':TodoTelescope' },
        { icon = '󰠮 ', key = 'n', desc = 'Project Scratchpad', action = ':lua Snacks.scratch()' },
        {
          icon = ' ',
          key = 'N',
          desc = 'Global Tasks',
          action = ":lua Snacks.scratch({ file = vim.fn.expand('~/Documents/Obsidian Vault/TODO.md'), name = 'Global Tasks', ft = 'markdown' })",
        },
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
        dirs = function()
          local projects = {}
          for _, p in ipairs(vim.fn.glob('~/Projects/*', false, true)) do
            p = vim.fs.normalize(p)
            if vim.fn.isdirectory(p) == 1 then table.insert(projects, p) end
          end
          return projects
        end,
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
    },
  },
  explorer = { enabled = false },
  gh = { enabled = false },
  indent = { enabled = false },
  input = { enabled = true },
  picker = {
    enabled = true,
    ui_select = true,
    sources = {
      projects = {
        dev = { '~/Projects' },
        patterns = { '.git', 'package.json', 'Cargo.toml', 'pyproject.toml', 'go.mod', 'Makefile' },
      },
      select = {
        layout = {
          preset = 'dropdown',
          preview = false,
        },
      },
    },
  },
  notifier = { enabled = true },
  quickfile = { enabled = true },
  scope = { enabled = true },
  scratch = { enabled = true },
  scroll = { enabled = false },
  statuscolumn = { enabled = false },
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
