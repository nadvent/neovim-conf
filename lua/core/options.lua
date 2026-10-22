-- ============================================================
-- SECTION 1: OPTIONS
-- Core Neovim settings, leaders, options
-- ============================================================
do
  -- Enable faster startup by caching compiled Lua modules
  vim.loader.enable()

  --  NOTE: Must happen before plugins are loaded
  --        (otherwise wrong leader will be used)
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '
  vim.g.have_nerd_font = true

  -- [[ Setting options ]]
  -- NOTE: You can change these options as you wish!
  --  For more options, you can see `:help option-list`

  vim.o.number = true
  vim.o.relativenumber = true
  vim.o.mouse = 'a'
  vim.o.showmode = false
  vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)
  vim.o.breakindent = true
  vim.o.undofile = true
  vim.o.ignorecase = true
  vim.o.smartcase = true
  vim.o.signcolumn = 'yes'
  vim.o.updatetime = 250
  vim.o.timeoutlen = 300
  vim.o.splitright = true
  vim.o.splitbelow = true
  vim.opt.colorcolumn = '80'
  vim.opt.swapfile = false
  vim.opt.autoindent = true
  vim.opt.expandtab = true
  vim.opt.tabstop = 4
  vim.opt.softtabstop = 4
  vim.opt.shiftwidth = 4
  vim.opt.termguicolors = true

  vim.o.list = true
  vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
  vim.o.inccommand = 'split'
  vim.o.cursorline = true
  vim.o.cmdheight = 0

  vim.o.scrolloff = 10

  vim.o.confirm = true

  vim.cmd.filetype 'plugin indent on'

  -- Change File System
  vim.g.loaded_netrwPlugin = 1
  vim.g.loaded_netrw = 1

  if vim.g.neovide then
    -- Put anything you want to happen only in Neovide here
    vim.o.guifont = 'Liga SFMono Nerd Font:h14' -- text below applies for VimScript
    vim.opt.linespace = 0
    vim.g.neovide_opacity = 1.0
    vim.g.neovide_normal_opacity = 0.7

    -- Hook into Noctalia's generated theme file
    local function apply_noctalia()
      local f = io.open(vim.fn.expand '~/.config/ghostty/themes/noctalia', 'r')
      if not f then return end

      local theme = {}
      for line in f:lines() do
        local k, v = line:match '^%s*([%w_%-]+)%s*=%s*(#[%x]+)'
        if k and v then theme[k] = v end
      end
      f:close()

      if theme['background'] then
        vim.api.nvim_set_hl(0, 'Normal', { bg = theme['background'], fg = theme['foreground'] })
        vim.api.nvim_set_hl(0, 'NormalFloat', { bg = theme['background'], fg = theme['foreground'] })
      end
    end

    apply_noctalia()
    vim.api.nvim_create_autocmd({ 'ColorScheme', 'FocusGained' }, { callback = apply_noctalia })
  end
end
