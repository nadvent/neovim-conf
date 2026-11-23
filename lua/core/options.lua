local util = require 'core.util'

-- Must happen before plugins are loaded so mappings use the intended leader.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

-- Line numbers & gutter (note: snacks.statuscolumn manages vim.o.statuscolumn)
vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = 'yes'

-- Editing & interaction
vim.o.mouse = 'a'
vim.o.showmode = false
vim.o.autoread = true
vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.scrolloff = 10
vim.o.confirm = true

vim.opt.textwidth = 80
vim.opt.swapfile = false
vim.opt.autoindent = true
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.termguicolors = true
vim.opt.sessionoptions:append 'globals'

vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.fillchars:append { fold = ' ' }

-- Folding (Treesitter by default, open on file load, syntax-highlighted foldtext)
vim.o.foldcolumn = '0'
vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldmethod = 'expr'
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.o.foldtext = ''
vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.cmdheight = 0

-- Defer clipboard sync until UIEnter to keep startup fast
vim.api.nvim_create_autocmd('UIEnter', {
  group = util.augroup 'clipboard_init',
  once = true,
  callback = function()
    vim.defer_fn(function() vim.o.clipboard = 'unnamedplus' end, 50)
  end,
})

-- Enable Neovim native UI2 subsystem (experimental)
pcall(function()
  require('vim._core.ui2').enable {
    enable = true,
    msg = {
      targets = 'cmd',
    },
  }
end)

vim.cmd.filetype 'plugin indent on'

-- Disable unused builtin plugins
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrw = 1
vim.g.loaded_fzf = 1

if vim.g.neovide then
  vim.opt.linespace = 6
  vim.g.neovide_opacity = 1.0
  vim.g.neovide_normal_opacity = 1.00
end
