local util = require 'core.util'

local M = {}

local initialized = false

local function setup_keymaps()
  local mappings = {
    { '<leader>ll', '<cmd>Leet<cr>', 'Menu / Dashboard' },
    { '<leader>lp', '<cmd>Leet list<cr>', 'Problem List' },
    { '<leader>ld', '<cmd>Leet daily<cr>', 'Daily Problem' },
    { '<leader>la', '<cmd>Leet random<cr>', 'Random Problem' },
    { '<leader>lr', '<cmd>Leet run<cr>', 'Run Tests' },
    { '<leader>ls', '<cmd>Leet submit<cr>', 'Submit Solution' },
    { '<leader>lc', '<cmd>Leet console<cr>', 'Toggle Console' },
    { '<leader>li', '<cmd>Leet info<cr>', 'Problem Info' },
    { '<leader>lt', '<cmd>Leet desc<cr>', 'Toggle Description' },
    { '<leader>lb', '<cmd>Leet tabs<cr>', 'Problem Tabs' },
    { '<leader>lx', '<cmd>Leet reset<cr>', 'Reset Code' },
    { '<leader>ly', '<cmd>Leet yank<cr>', 'Yank Code' },
    { '<leader>lo', '<cmd>Leet open<cr>', 'Open in Browser' },
    { '<leader>lL', '<cmd>Leet lang<cr>', 'Change Language' },
    { '<leader>lq', '<cmd>Leet exit<cr>', 'Exit' },
  }

  for _, m in ipairs(mappings) do
    vim.keymap.set('n', m[1], m[2], { desc = m[3] })
  end

  vim.schedule(function()
    local ok_wk, wk = pcall(require, 'which-key')
    if ok_wk then wk.add { { '<leader>l', group = 'LeetCode' } } end
  end)
end

function M.setup()
  if initialized then return end
  initialized = true

  vim.pack.add {
    util.gh 'nvim-lua/plenary.nvim',
    util.gh 'MunifTanjim/nui.nvim',
    util.gh 'kawre/leetcode.nvim',
  }

  require('leetcode').setup {
    lang = 'python3',
    storage = {
      home = util.PATHS.leetcode,
    },
    picker = {
      provider = 'mini-picker',
    },
  }

  setup_keymaps()
end

return M
