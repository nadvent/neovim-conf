local util = require 'core.util'

local M = {}

vim.pack.add {
  util.gh 'dchinmay2/clangd_extensions.nvim',
}

require('clangd_extensions').setup {
  inlay_hints = {
    inline = vim.fn.has 'nvim-0.10' == 1,
    only_current_line = false,
    show_parameter_hints = true,
  },
  ast = {
    role_icons = {
      type = '',
      declaration = '',
      expression = '',
      specifier = '',
      statement = '',
      ['template argument'] = '',
    },
  },
}

--- Attach C/C++ buffer-local keymaps.
---@param buf integer
function M.on_filetype(buf)
  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = buf, desc = desc }) end

  map('<leader>ch', '<cmd>ClangdSwitchSourceHeader<cr>', 'Switch Header/Source')
  map('<leader>ct', '<cmd>ClangdTypeHierarchy<cr>', 'Type Hierarchy')
  map('<leader>cm', '<cmd>ClangdMemoryUsage<cr>', 'Memory Usage')
  map('<leader>cA', '<cmd>ClangdAST<cr>', 'View AST')
  map('<leader>cS', '<cmd>ClangdSymbolInfo<cr>', 'Clangd Symbol Info')
end

return M
