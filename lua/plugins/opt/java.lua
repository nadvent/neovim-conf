-- plugins/opt/java.lua
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'mfussenegger/nvim-jdtls',
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'java',
  callback = function(args)
    local jdtls = require 'jdtls'
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc }) end

    -- Java Code Refactorings
    map('n', '<leader>co', jdtls.organize_imports, 'Organize Imports')
    map('n', '<leader>cv', jdtls.extract_variable, 'Extract Variable')
    map('v', '<leader>cv', [[<esc><cmd>lua require('jdtls').extract_variable(true)<cr>]], 'Extract Variable')
    map('v', '<leader>cm', [[<esc><cmd>lua require('jdtls').extract_method(true)<cr>]], 'Extract Method')

    -- Java Test Runner
    map('n', '<leader>dtc', jdtls.test_class, 'Test Java Class')
    map('n', '<leader>dtm', jdtls.test_nearest_method, 'Test Nearest Method')
  end,
})
