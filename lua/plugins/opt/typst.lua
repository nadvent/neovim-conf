local util = require 'core.util'

local M = {}

vim.pack.add {
  util.gh 'chomosuke/typst-preview.nvim',
  util.gh 'pxwg/math-conceal.nvim',
}

pcall(function()
  require('typst-preview').setup {
    open_cmd = nil,
    dependencies_bin = {
      ['tinymist'] = 'tinymist',
      ['websocat'] = nil,
    },
  }
end)

local function setup_math_conceal()
  local ok, mc = pcall(require, 'math-conceal')
  if not ok then ok, mc = pcall(require, 'math-conceal.nvim') end
  if not ok or type(mc) ~= 'table' or not mc.setup then
    vim.notify('math-conceal plugin module could not be loaded', vim.log.levels.WARN)
    return
  end

  mc.setup {
    image = {
      enabled = true,
      renderers = {
        typst = {
          filetypes = { 'typst' },
          code_render = {
            exclude = { 'table', 'grid', 'figure', 'columns' },
          },
          header = [[
              #show math.equation.where(block: false): set text(size: 5.5pt)
            ]],
        },
        markdown = {
          filetypes = { 'markdown' },
          mitex_package = '@preview/mitex:0.2.7',
        },
      },
    },
  }
end

setup_math_conceal()

--- Attach Typst buffer-local keymaps and window-local gutter settings.
---@param buf integer
function M.on_filetype(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].statuscolumn = ''
  end

  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = buf, desc = desc }) end
  map('<leader>uv', '<cmd>TypstPreviewToggle<cr>', 'UI: Toggle Typst Preview')
  map('<leader>uf', '<cmd>TypstPreviewFollowCursorToggle<cr>', 'UI: Toggle Typst Follow Cursor')
end

return M
