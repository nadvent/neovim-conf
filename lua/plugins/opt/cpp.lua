-- plugins/opt/cpp.lua
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'dchinmay2/clangd_extensions.nvim',
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

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'c', 'cpp' },
  callback = function(args)
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc }) end

    -- Header / Source navigation
    map('n', '<leader>ch', '<cmd>ClangdSwitchSourceHeader<cr>', 'Switch Header/Source')

    -- Clangd Advanced Inspections
    map('n', '<leader>ct', '<cmd>ClangdTypeHierarchy<cr>', 'Type Hierarchy')
    map('n', '<leader>cm', '<cmd>ClangdMemoryUsage<cr>', 'Memory Usage')
    map('n', '<leader>cA', '<cmd>ClangdAST<cr>', 'View AST')
    map('n', '<leader>cs', '<cmd>ClangdSymbolInfo<cr>', 'Symbol Info')

    -- Overseer Build & Run
    map('n', '<leader>rr', '<cmd>OverseerRun<cr>', 'Run Task (Overseer)')
    map('n', '<leader>rt', '<cmd>OverseerToggle<cr>', 'Toggle Overseer')
  end,
})
