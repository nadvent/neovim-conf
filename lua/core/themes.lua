local util = require 'core.util'

local M = {}

M.default_colorscheme = 'koda-light'

local lazy_theme_specs = {
  { src = util.gh 'catppuccin/nvim', pattern = 'catppuccin.*', pack = 'nvim' },
  { src = util.gh 'EdenEast/nightfox.nvim', pattern = '.*fox', pack = 'nightfox.nvim' },
  { src = util.gh 'projekt0n/github-nvim-theme', pattern = 'github_.*', pack = 'github-nvim-theme' },
  { src = util.gh 'rose-pine/neovim', pattern = 'rose%-pine.*', pack = 'neovim' },
  { src = util.gh 'sainnhe/everforest', pattern = 'everforest.*', pack = 'everforest' },
  { src = util.gh 'folke/tokyonight.nvim', pattern = 'tokyonight.*', pack = 'tokyonight.nvim' },
}

-- Register optional themes without eagerly sourcing them at startup
vim.pack.add(
  vim.tbl_map(function(item) return item.src end, lazy_theme_specs),
  { load = function() end }
)

-- Load the active startup colorscheme package
vim.pack.add { util.gh 'oskarnurm/koda.nvim' }

vim.api.nvim_create_autocmd('ColorSchemePre', {
  group = util.augroup 'lazy_colorscheme_loader',
  callback = function(args)
    for _, item in ipairs(lazy_theme_specs) do
      if args.match:match('^' .. item.pattern .. '$') then
        pcall(vim.cmd.packadd, item.pack)
        break
      end
    end
  end,
})

local function apply_syntax_overrides()
  vim.api.nvim_set_hl(0, '@keyword', { italic = true })
  vim.api.nvim_set_hl(0, '@keyword.function', { italic = true })
  vim.api.nvim_set_hl(0, '@type.builtin', { italic = true })
end

vim.api.nvim_create_autocmd('ColorScheme', {
  group = util.augroup 'theme_syntax_overrides',
  callback = apply_syntax_overrides,
})

require('koda').setup {}
vim.g.everforest_transparent_background = 1

vim.cmd.colorscheme(M.default_colorscheme)
apply_syntax_overrides()

-- Initialize theme profile & UI highlight manager
require('core.noctalia').setup {
  standard_colorscheme = M.default_colorscheme,
}

return M
