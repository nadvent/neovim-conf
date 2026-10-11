
---@param repo string
---@return string
---
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
vim.pack.add { gh 'lewis6991/gitsigns.nvim' }
vim.pack.add { gh 'folke/which-key.nvim' }
vim.pack.add { gh 'folke/todo-comments.nvim' }
vim.pack.add { gh 'SmiteshP/nvim-navic' }
vim.pack.add {
  {src = 'https://codeberg.org/cryptomilk/nvim-pack-ui'}
}
vim.pack.add({
  { src = 'https://github.com/nvim-tree/nvim-web-devicons' }
})

local keymaps = require('core.keymaps')

require('guess-indent').setup {}

local gitsigns = require('gitsigns')
gitsigns.setup {
  signs = {
    add = { text = '+' },
    change = { text = '~' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
  },

  on_attach = function(bufnr)
    keymaps.gitsigns(bufnr, gitsigns)
  end,


}


require('which-key').setup {
  -- Delay between pressing a key and opening which-key (milliseconds)
  delay = 0,
  icons = { mappings = vim.g.have_nerd_font },
  -- Document existing key chains
  spec = {
    { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
    { '<leader>t', group = '[T]oggle' },
    { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } }, -- Enable gitsigns recommended keymaps first
    { 'gr', group = 'LSP Actions', mode = { 'n' } },
  },
}

-- Highlight todo, notes, etc in comments
require('todo-comments').setup { signs = false }

local navic = require("nvim-navic")

vim.lsp.config('clangd', {
    on_attach = function(client, bufnr)
        navic.attach(client, bufnr)
    end
})



