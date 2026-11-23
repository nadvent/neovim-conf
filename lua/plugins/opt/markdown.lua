local util = require 'core.util'

local M = {}

vim.pack.add {
  util.gh 'MeanderingProgrammer/render-markdown.nvim',
  util.gh 'blackhat-7/vellum.nvim',
}

require('render-markdown').setup {
  file_types = { 'markdown', 'quarto' },
  latex = { enabled = true },
  pipe_table = {
    -- Prevent conceal_lines + virt_lines row-swapping on wide wrapped tables
    wrap = false,
    cell = 'trimmed',
  },
  anti_conceal = {
    ignore = {
      table_border = true,
    },
  },
}

-- Disable Snacks smooth-scrolling inside Vellum's preview buffer to avoid WinScrolled feedback loops
vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
  group = util.augroup 'vellum_scroll',
  pattern = 'vellum://*',
  callback = function(args) vim.b[args.buf].snacks_scroll = false end,
})

pcall(function()
  require('vellum').setup {
    max_width = 100,
  }
end)

--- Attach Markdown/Quarto buffer-local keymaps.
---@param buf integer
function M.on_filetype(buf)
  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = buf, desc = desc }) end

  map('<leader>mp', '<cmd>Vellum<cr>', 'Toggle Markdown Preview (Vellum)')
  map('<leader>mz', function() require('vellum').zoom() end, 'Zoom Diagram / Image')
  map('<leader>me', '<cmd>Vellum export<cr>', 'Export Markdown to PDF')
  map('<leader>um', '<cmd>RenderMarkdown toggle<cr>', 'Toggle In-Buffer Markdown Render')
end

return M
