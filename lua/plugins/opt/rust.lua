local util = require 'core.util'

local M = {}

vim.pack.add {
  util.gh 'mrcjkb/rustaceanvim',
  util.gh 'saecki/crates.nvim',
}

require('crates').setup {
  lsp = {
    enabled = true,
    actions = true,
    completion = true,
    hover = true,
  },
}

vim.g.rustaceanvim = {
  server = {
    default_settings = {
      ['rust-analyzer'] = {
        checkOnSave = true,
        check = { command = 'clippy' },
      },
    },
  },
}

--- Attach Rust buffer-local keymaps.
---@param buf integer
function M.on_filetype(buf)
  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = buf, desc = desc }) end

  map('K', function() vim.cmd.RustLsp { 'hover', 'actions' } end, 'Rust Hover Actions')
  map('<leader>ca', function() vim.cmd.RustLsp 'codeAction' end, 'Rust Code Action')
  map('<leader>cR', function() vim.cmd.RustLsp 'runnables' end, 'Rust Runnables')
  map('<leader>cD', function() vim.cmd.RustLsp 'debuggables' end, 'Rust Debuggables')
  map('<leader>cm', function() vim.cmd.RustLsp 'expandMacro' end, 'Expand Macro')
  map('<leader>ct', function() vim.cmd.RustLsp 'testables' end, 'Rust Testables')
  map('<leader>ce', function() vim.cmd.RustLsp 'explainError' end, 'Explain Compiler Error')
end

return M
