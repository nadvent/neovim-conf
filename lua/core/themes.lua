---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add { gh 'catppuccin/nvim' }
vim.pack.add { gh 'EdenEast/nightfox.nvim' }
vim.pack.add { gh 'projekt0n/github-nvim-theme' }
vim.pack.add { gh 'rose-pine/neovim' }
vim.pack.add { gh 'sainnhe/everforest' }
vim.pack.add { gh 'folke/tokyonight.nvim' }

-- require("catppuccin").setup({
-- 	flavour = "latte",
-- 	transparent_background = true,
-- })
-- require("github-theme").setup({
-- 	options = {
-- 		transparent = true,
-- 	}
-- })
require('nightfox').setup {
  options = {
    transparent = true,
  },
}
-- require("rose-pine").setup({
-- 	variant = "dawn",
-- 	styles = { transparency = true},
-- })
require('tokyonight').setup {
  transparent = true,
  styles = {
    comments = { italic = false }, -- Disable italics in comments
  },
}
--
vim.g.everforest_transparent_background = 1
vim.cmd.colorscheme 'dayfox'

-- Force keywords and types to italic
vim.api.nvim_set_hl(0, '@keyword', { italic = true })
vim.api.nvim_set_hl(0, '@keyword.function', { italic = true })
vim.api.nvim_set_hl(0, '@type.builtin', { italic = true })
-- vim.api.nvim_set_hl(0, "@comment", { italic = true })

-- Auto-theming from Ghostty Noctalia
require('core.noctalia').setup()
