local util = require 'core.util'

local M = {}

vim.pack.add {
  util.gh 'mfussenegger/nvim-jdtls',
}

--- Attach Java buffer-local keymaps.
---@param buf integer
function M.on_filetype(buf)
  local jdtls = require 'jdtls'
  local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc }) end

  map('n', '<leader>cO', jdtls.organize_imports, 'Java: Organize Imports')
  map('n', '<leader>cv', jdtls.extract_variable, 'Extract Variable')
  map('v', '<leader>cv', [[<esc><cmd>lua require('jdtls').extract_variable(true)<cr>]], 'Extract Variable')
  map('v', '<leader>cm', [[<esc><cmd>lua require('jdtls').extract_method(true)<cr>]], 'Extract Method')

  map('n', '<leader>dtc', jdtls.test_class, 'Test Java Class')
  map('n', '<leader>dtm', jdtls.test_nearest_method, 'Test Nearest Method')
end

return M
