local util = require 'core.util'

local gh = util.gh

vim.pack.add {
  gh 'lewis6991/gitsigns.nvim',
  gh 'kdheepak/lazygit.nvim',
  gh 'HarshK97/diffmantic.nvim',
}

require('gitsigns').setup {
  signs = {
    add = { text = '+' },
    change = { text = '~' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
  },
  on_attach = function(bufnr)
    local gs = require 'gitsigns'
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc }) end

    map('n', ']c', function()
      if vim.wo.diff then
        vim.cmd.normal { ']c', bang = true }
      else
        gs.nav_hunk 'next'
      end
    end, 'Jump to next git change')

    map('n', '[c', function()
      if vim.wo.diff then
        vim.cmd.normal { '[c', bang = true }
      else
        gs.nav_hunk 'prev'
      end
    end, 'Jump to previous git change')

    map('n', '<leader>hs', gs.stage_hunk, 'Git: Stage hunk')
    map('n', '<leader>hr', gs.reset_hunk, 'Git: Reset hunk')
    map('v', '<leader>hs', function() gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, 'Git: Stage selection')
    map('v', '<leader>hr', function() gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, 'Git: Reset selection')
    map('n', '<leader>hS', gs.stage_buffer, 'Git: Stage buffer')
    map('n', '<leader>hR', gs.reset_buffer, 'Git: Reset buffer')
    map('n', '<leader>hp', gs.preview_hunk, 'Git: Preview hunk')
    map('n', '<leader>hi', gs.preview_hunk_inline, 'Git: Preview inline')
    map('n', '<leader>hb', function() gs.blame_line { full = true } end, 'Git: Blame line')
    map('n', '<leader>hd', gs.diffthis, 'Git: Diff index')
    map('n', '<leader>hD', function() gs.diffthis '~' end, 'Git: Diff last commit')
    map('n', '<leader>hQ', function() gs.setqflist 'all' end, 'Git: Quickfix all hunks')
    map('n', '<leader>hq', gs.setqflist, 'Git: Quickfix file hunks')

    map('n', '<leader>ub', gs.toggle_current_line_blame, 'UI: Toggle Git Blame')
    map('n', '<leader>uW', gs.toggle_word_diff, 'UI: Toggle Git Word Diff')
    map({ 'o', 'x' }, 'ih', gs.select_hunk, 'Git hunk text object')
  end,
}

pcall(function() require('diffmantic').setup() end)

vim.api.nvim_create_user_command('DiffmanticClear', function()
  local ok_ui, ui = pcall(require, 'diffmantic.ui')
  if ok_ui then
    ui.clear_highlights(vim.api.nvim_get_current_buf())
    vim.notify('Diffmantic highlights cleared', vim.log.levels.INFO)
  end
end, { desc = 'Clear Diffmantic semantic diff highlights' })
