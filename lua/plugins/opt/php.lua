-- plugins/opt/php.lua
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'adalessa/laravel.nvim',
}

require('laravel').setup()

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'php',
  callback = function(args)
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc }) end

    map('n', '<leader>la', '<cmd>Laravel artisan<cr>', 'Laravel: Artisan Commands')
    map('n', '<leader>lr', '<cmd>Laravel routes<cr>', 'Laravel: Routes')
    map('n', '<leader>lm', '<cmd>Laravel related<cr>', 'Laravel: Related Models/Views')
  end,
})
