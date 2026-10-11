do
  -- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`

  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })
end
