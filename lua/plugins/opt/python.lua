local util = require 'core.util'

local M = {}

vim.pack.add {
  util.gh 'jmbuhr/otter.nvim',
  util.gh 'quarto-dev/quarto-nvim',
  util.gh 'linux-cultist/venv-selector.nvim',
  util.gh 'mfussenegger/nvim-dap-python',
}

require('quarto').setup {
  lspFeatures = {
    enabled = true,
    chunks = 'curly',
    languages = { 'python' },
  },
  codeRunner = {
    enabled = true,
    default_method = 'molten',
  },
}

require('venv-selector').setup {
  settings = {
    options = {
      notify_user_on_venv_activation = true,
    },
  },
}

require('dap-python').setup 'python3'

--- Attach Python/Quarto buffer-local keymaps.
---@param buf integer
function M.on_filetype(buf)
  local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc }) end

  map('n', '<leader>cv', '<cmd>VenvSelect<cr>', 'Select Python Venv')
  map('n', ',v', '<cmd>VenvSelect<cr>', 'Select Python Venv')

  map('n', '<leader>rp', require('quarto').quartoPreview, 'Quarto Preview')
  map('n', '<leader>rc', require('quarto.runner').run_cell, 'Run Current Cell')
  map('n', '<leader>rA', require('quarto.runner').run_all_cells, 'Quarto: Run All Cells')
  map('v', '<leader>r', require('quarto.runner').run_range, 'Run Selected Range')

  map('n', '<leader>dpm', require('dap-python').test_method, 'Debug Test Method')
  map('n', '<leader>dpc', require('dap-python').test_class, 'Debug Test Class')
  map('v', '<leader>dps', require('dap-python').debug_selection, 'Debug Selection')
end

return M
