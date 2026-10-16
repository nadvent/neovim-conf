-- plugins/opt/markdown.lua
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'MeanderingProgrammer/render-markdown.nvim',
  gh 'iamcco/markdown-preview.nvim',
}

require('render-markdown').setup {
  file_types = { 'markdown', 'quarto' },
  latex = { enabled = true },
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'quarto' },
  callback = function(args)
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc }) end

    map('n', '<leader>mp', '<cmd>MarkdownPreviewToggle<cr>', 'Toggle Markdown Browser Preview')
    map('n', '<leader>um', '<cmd>RenderMarkdown toggle<cr>', 'Toggle In-Buffer Markdown Render')
  end,
})
