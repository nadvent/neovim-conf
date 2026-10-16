local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'lewis6991/gitsigns.nvim',
  gh 'kdheepak/lazygit.nvim',
}

-- Lazygit quick toggle
vim.keymap.set('n', '<leader>gg', '<cmd>LazyGit<cr>', { desc = 'Open LazyGit' })

local gitsigns = require 'gitsigns'
gitsigns.setup {
  signs = {
    add = { text = '+' },
    change = { text = '~' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
  },
  on_attach = function(bufnr)
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    -- Navigation
    map('n', ']c', function()
      if vim.wo.diff then vim.cmd.normal { ']c', bang = true } else gitsigns.nav_hunk 'next' end
    end, 'Jump to next git change')

    map('n', '[c', function()
      if vim.wo.diff then vim.cmd.normal { '[c', bang = true } else gitsigns.nav_hunk 'prev' end
    end, 'Jump to previous git change')

    -- Actions (Normal & Visual)
    map('n', '<leader>hs', gitsigns.stage_hunk, 'Git: Stage hunk')
    map('n', '<leader>hr', gitsigns.reset_hunk, 'Git: Reset hunk')
    map('v', '<leader>hs', function() gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, 'Git: Stage selection')
    map('v', '<leader>hr', function() gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, 'Git: Reset selection')
    map('n', '<leader>hS', gitsigns.stage_buffer, 'Git: Stage buffer')
    map('n', '<leader>hR', gitsigns.reset_buffer, 'Git: Reset buffer')
    map('n', '<leader>hp', gitsigns.preview_hunk, 'Git: Preview hunk')
    map('n', '<leader>hi', gitsigns.preview_hunk_inline, 'Git: Preview inline')
    map('n', '<leader>hb', function() gitsigns.blame_line { full = true } end, 'Git: Blame line')
    map('n', '<leader>hd', gitsigns.diffthis, 'Git: Diff index')
    map('n', '<leader>hD', function() gitsigns.diffthis '~' end, 'Git: Diff last commit')
    map('n', '<leader>hQ', function() gitsigns.setqflist 'all' end, 'Git: Quickfix all hunks')
    map('n', '<leader>hq', gitsigns.setqflist, 'Git: Quickfix file hunks')

    -- Toggles & Text Objects
    map('n', '<leader>tb', gitsigns.toggle_current_line_blame, 'Toggle git blame')
    map('n', '<leader>tw', gitsigns.toggle_word_diff, 'Toggle intra-line word diff')
    map({ 'o', 'x' }, 'ih', gitsigns.select_hunk, 'Git hunk text object')
  end,
}
