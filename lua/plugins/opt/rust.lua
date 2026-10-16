-- plugins/opt/rust.lua
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'mrcjkb/rustaceanvim',
  gh 'saecki/crates.nvim',
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

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'rust',
  callback = function(args)
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc }) end

    map('n', 'K', function() vim.cmd.RustLsp { 'hover', 'actions' } end, 'Rust Hover Actions')
    map('n', '<leader>ca', function() vim.cmd.RustLsp 'codeAction' end, 'Rust Code Action')
    map('n', '<leader>cR', function() vim.cmd.RustLsp 'runnables' end, 'Rust Runnables')
    map('n', '<leader>cd', function() vim.cmd.RustLsp 'debuggables' end, 'Rust Debuggables')
    map('n', '<leader>cm', function() vim.cmd.RustLsp 'expandMacro' end, 'Expand Macro')
    map('n', '<leader>ct', function() vim.cmd.RustLsp 'testables' end, 'Rust Testables')
    map('n', '<leader>ce', function() vim.cmd.RustLsp 'explainError' end, 'Explain Compiler Error')
  end,
})
