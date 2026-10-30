---@param repo string
---@return string
---
local function gh(repo) return 'https://github.com/' .. repo end

---@type (string | vim.pack.Spec)[]
local telescope_plugins = {
  gh 'nvim-lua/plenary.nvim',
  gh 'nvim-telescope/telescope.nvim',
  -- gh 'nvim-telescope/telescope-ui-select.nvim',
}
if vim.fn.executable 'make' == 1 then table.insert(telescope_plugins, gh 'nvim-telescope/telescope-fzf-native.nvim') end

-- NOTE: You can install multiple plugins at once
vim.pack.add(telescope_plugins)

local function init_telescope()
  if _G._telescope_configured then return end
  _G._telescope_configured = true
  local telescope = require 'telescope'
  telescope.setup {
    extensions = {
      ['ui-select'] = { require('telescope.themes').get_dropdown() },
    },
  }
  pcall(telescope.load_extension, 'fzf')
  pcall(telescope.load_extension, 'todo-comments')
end

_G.init_telescope = init_telescope

vim.api.nvim_create_autocmd('CmdUndefined', {
  pattern = { 'Telescope', 'TodoTelescope' },
  callback = function() init_telescope() end,
})
