-- ============================================================
-- SECTION 2: KEYMAPS & AUTOCMDS
-- basic keymaps, basic autocmds
-- ============================================================
do
  -- [[ Basic Keymaps ]]
  --  See `:help vim.keymap.set()`

  vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Diagnostic Config & Keymaps
  --  See `:help vim.diagnostic.Opts`
  vim.diagnostic.config {
    update_in_insert = false,
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = { min = vim.diagnostic.severity.WARN } },

    -- Can switch between these as you prefer
    virtual_text = true, -- Text shows up at the end of the line
    virtual_lines = false, -- Text shows up underneath the line, with virtual lines

    -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
    jump = {
      on_jump = function(_, bufnr)
        vim.diagnostic.open_float {
          bufnr = bufnr,
          scope = 'cursor',
          focus = false,
        }
      end,
    },
  }

  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

  -- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
  -- or just use <C-\><C-n> to exit terminal mode
  vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  --  See `:help wincmd` for a list of all window commands
  vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

end


-- Gitsigns.nvim

local M = {}

function M.gitsigns(bufnr, gitsigns)
  local opts = { buffer = bufnr }

  -- Navigation
  vim.keymap.set('n', ']c', function()
    if vim.wo.diff then
      vim.cmd.normal { ']c', bang = true }
    else
      gitsigns.nav_hunk('next')
    end
  end, vim.tbl_extend('force', opts, {
    desc = 'Jump to next git change',
  }))

  vim.keymap.set('n', '[c', function()
    if vim.wo.diff then
      vim.cmd.normal { '[c', bang = true }
    else
      gitsigns.nav_hunk('prev')
    end
  end, vim.tbl_extend('force', opts, {
    desc = 'Jump to previous git change',
  }))

  -- Stage and reset hunks
  vim.keymap.set('n', '<leader>hs',
    gitsigns.stage_hunk,
    vim.tbl_extend('force', opts, {
      desc = 'Git stage hunk',
    })
  )

  vim.keymap.set('n', '<leader>hr',
    gitsigns.reset_hunk,
    vim.tbl_extend('force', opts, {
      desc = 'Git reset hunk',
    })
  )

  -- Preview a hunk
  vim.keymap.set('n', '<leader>hp',
    gitsigns.preview_hunk,
    vim.tbl_extend('force', opts, {
      desc = 'Git preview hunk',
    })
  )
end

return M
