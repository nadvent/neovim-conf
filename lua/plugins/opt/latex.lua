local util = require 'core.util'

local M = {}

vim.pack.add {
  util.gh 'lervag/vimtex',
}

vim.g.vimtex_view_method = 'zathura'
vim.g.vimtex_compiler_method = 'latexmk'
vim.g.vimtex_quickfix_mode = 0

--- Attach LaTeX/BibTeX buffer-local keymaps.
---@param buf integer
function M.on_filetype(buf)
  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = buf, desc = desc }) end

  map('<leader>ll', '<cmd>VimtexCompile<cr>', 'Toggle LaTeX Compiler')
  map('<leader>lv', '<cmd>VimtexView<cr>', 'View LaTeX PDF')
  map('<leader>lc', '<cmd>VimtexClean<cr>', 'Clean LaTeX Aux Files')
  map('<leader>lt', '<cmd>VimtexTocToggle<cr>', 'Toggle LaTeX TOC')
end

return M
