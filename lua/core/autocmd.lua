do
  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`

  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })

  vim.api.nvim_create_autocmd("BufReadPre", {
    group = vim.api.nvim_create_augroup("PersistenceNative", { clear = true }),
    once = true,
    callback = function()
      require("persistence").load()
    end,
  })
end
