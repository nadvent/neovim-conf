local util = require 'core.util'

local M = {}

vim.pack.add {
  util.gh 'adalessa/laravel.nvim',
}

require('laravel').setup()

--- Attach PHP/Laravel buffer-local keymaps.
---@param buf integer
function M.on_filetype(buf)
  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = buf, desc = desc }) end

  map('<leader>la', '<cmd>Laravel artisan<cr>', 'Laravel: Artisan Commands')
  map('<leader>lr', '<cmd>Laravel routes<cr>', 'Laravel: Routes')
  map('<leader>lm', '<cmd>Laravel related<cr>', 'Laravel: Related Models/Views')
end

return M
