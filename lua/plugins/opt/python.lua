-- plugins/opt/python.lua
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'jmbuhr/otter.nvim',
  gh 'quarto-dev/quarto-nvim',
  gh 'linux-cultist/venv-selector.nvim',
  gh 'mfussenegger/nvim-dap-python',
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

-- Uses system python-debugpy installed in shell
require('dap-python').setup 'python3'

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'python', 'quarto' },
  callback = function(args)
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc }) end

    -- Environment selection
    map('n', '<leader>cv', '<cmd>VenvSelect<cr>', 'Select Python Venv')
    map('n', ',v', '<cmd>VenvSelect<cr>', 'Select Python Venv')

    -- Quarto / Code cell execution
    map('n', '<leader>qp', require('quarto').quartoPreview, 'Quarto Preview')
    map('n', '<leader>rc', require('quarto.runner').run_cell, 'Run Current Cell')
    map('n', '<leader>ra', require('quarto.runner').run_all_cells, 'Run All Cells')
    map('v', '<leader>r', require('quarto.runner').run_range, 'Run Selected Range')

    -- DAP-Python testing & debugging
    map('n', '<leader>dpm', require('dap-python').test_method, 'Debug Test Method')
    map('n', '<leader>dpc', require('dap-python').test_class, 'Debug Test Class')
    map('v', '<leader>dps', require('dap-python').debug_selection, 'Debug Selection')
  end,
})
