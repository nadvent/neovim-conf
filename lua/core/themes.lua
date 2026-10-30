---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

-- On-demand theme loader: lazy-load theme packages before colorscheme switch
local theme_packages = {
  ['catppuccin.*'] = 'nvim',
  ['.*fox'] = 'nightfox.nvim',
  ['github_.*'] = 'github-nvim-theme',
  ['rose%-pine.*'] = 'neovim',
  ['everforest.*'] = 'everforest',
  ['tokyonight.*'] = 'tokyonight.nvim',
}

vim.api.nvim_create_autocmd('ColorSchemePre', {
  callback = function(args)
    for pattern, name in pairs(theme_packages) do
      if args.match:match('^' .. pattern .. '$') then
        pcall(vim.cmd.packadd, name)
        break
      end
    end
  end,
})

-- Load the currently active colorscheme package
vim.pack.add { gh 'projekt0n/github-nvim-theme' }

-- require("catppuccin").setup({
-- 	flavour = "latte",
-- 	transparent_background = true,
-- })
require('github-theme').setup {
  options = {
    transparent = false,
  },
}
-- require('nightfox').setup {
--   options = {
--     transparent = false,
--   },
-- }
-- require("rose-pine").setup({
-- 	variant = "dawn",
-- 	styles = { transparency = true},
-- })
-- require('tokyonight').setup {
--   transparent = false,
--   styles = {
--     comments = { italic = false }, -- Disable italics in comments
--   },
-- }
--
vim.g.everforest_transparent_background = 1
-- github_light, dayfox, rose-pine, tokyonight-light
vim.cmd.colorscheme 'github_light'

-- Force keywords and types to italic
vim.api.nvim_set_hl(0, '@keyword', { italic = true })
vim.api.nvim_set_hl(0, '@keyword.function', { italic = true })
vim.api.nvim_set_hl(0, '@type.builtin', { italic = true })
-- vim.api.nvim_set_hl(0, "@comment", { italic = true })

-- Auto-theming from Ghostty Noctalia
-- require('core.noctalia').setup()
