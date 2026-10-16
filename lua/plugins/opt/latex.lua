-- plugins/opt/latex.lua
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'lervag/vimtex',
}

vim.g.vimtex_view_method = 'zathura' -- Or 'sioyek' / 'general'
vim.g.vimtex_compiler_method = 'latexmk'
vim.g.vimtex_quickfix_mode = 0

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'tex', 'bib' },
  callback = function(args)
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc }) end

    map('n', '<leader>ll', '<cmd>VimtexCompile<cr>', 'Toggle LaTeX Compiler')
    map('n', '<leader>lv', '<cmd>VimtexView<cr>', 'View LaTeX PDF')
    map('n', '<leader>lc', '<cmd>VimtexClean<cr>', 'Clean LaTeX Aux Files')
    map('n', '<leader>lt', '<cmd>VimtexTocToggle<cr>', 'Toggle LaTeX TOC')
  end,
})
