-- Enable faster startup by caching compiled Lua modules
vim.loader.enable()

-- 1. Core editor options & plugin build hooks (must precede any vim.pack.add)
require 'core.options'
require 'plugins.init'

-- 2. Colorscheme & dynamic theming
require 'core.themes'

-- 3. Core autocommands & project-scoped integrations
require 'core.autocmd'

-- 4. Plugin layers
require 'plugins.ux'
require 'plugins.pick'
require 'plugins.code'
require 'plugins.git'

-- 5. Diagnostics, keymaps, and statusline
require('core.diagnostics').setup()
require 'core.keymaps'
require 'plugins.statusline'

-- Defer task tracker & automated time footprint setup after UIEnter to preserve startup speed
vim.api.nvim_create_autocmd('UIEnter', {
  group = require('core.util').augroup 'tasks_init',
  once = true,
  callback = function()
    vim.defer_fn(function()
      local ok, err = pcall(function() require('tasks').setup() end)
      if not ok then vim.notify('tasks.setup error: ' .. tostring(err), vim.log.levels.ERROR) end
    end, 150)
  end,
})

-- 6. On-demand language toolchains (loaded & attached per FileType)
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
  group = require('core.util').augroup 'opt_lang_loader',
  callback = function(args)
    local module_name = opt_langs[args.match]
    if not module_name then return end

    local ok, mod = pcall(require, 'plugins.opt.' .. module_name)
    if not ok then
      vim.notify(('Failed loading plugins.opt.%s:\n%s'):format(module_name, mod), vim.log.levels.ERROR)
      return
    end

    if type(mod) == 'table' and mod.on_filetype then mod.on_filetype(args.buf, args.match) end
  end,
})
