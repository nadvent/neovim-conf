local function gh(repo) return 'https://github.com/' .. repo end

-- 1. Plugin Declarations (batched)
vim.pack.add {
  gh 'NMAC427/guess-indent.nvim',
  { src = 'https://codeberg.org/cryptomilk/nvim-pack-ui' },
  gh 'Bekaboo/dropbar.nvim',
  gh 'mikavilpas/yazi.nvim',
  gh 'folke/persistence.nvim',
  gh 'nvim-mini/mini.nvim',
  gh 'folke/todo-comments.nvim',
  gh 'folke/noice.nvim',
  gh 'folke/trouble.nvim',
  gh 'folke/flash.nvim',
  gh 'saghen/blink.indent',
  gh 'MunifTanjim/nui.nvim',
  gh 'nvim-pack/nvim-spectre',
}

-- 2. Fast / Zero-Config Setups
require('guess-indent').setup {}
require('todo-comments').setup { signs = false }
require('yazi').setup { open_for_directories = true }
require('blink.indent').setup()
require('flash').setup()

-- 2.5 Lazy-loading

vim.api.nvim_create_user_command('Spectre', function() require('spectre').open() end, {})
vim.schedule(function() require('trouble').setup {} end)

-- 3. Session Management (persistence + colocated autocmd)
require('persistence').setup()
vim.api.nvim_create_autocmd('VimEnter', {
  group = vim.api.nvim_create_augroup('persistence', { clear = true }),
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 then require('persistence').load() end
  end,
})

-- 4. Mini.nvim suite
if vim.g.have_nerd_font then
  require('mini.icons').setup()
  MiniIcons.mock_nvim_web_devicons()
end

require('mini.ai').setup {
  mappings = { around_next = 'aa', inside_next = 'ii' },
  n_lines = 500,
}
require('mini.surround').setup()
require('mini.pairs').setup()

-- 5. Command line & UI enhancements
require('noice').setup {
  notify = { enabled = false },
  lsp = {
    override = {
      ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
      ['vim.lsp.util.stylize_markdown'] = true,
    },
  },
  presets = {
    bottom_search = true,
    command_palette = true,
    long_message_to_split = true,
    inc_rename = false,
    lsp_doc_border = false,
  },
}
