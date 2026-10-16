-- plugins/opt/typst.lua
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'chomosuke/typst-preview.nvim',
}

require('typst-preview').setup {
  open_cmd = nil, -- Uses default system browser
  dependencies_bin = {
    ['tinymist'] = 'tinymist',
    ['websocat'] = nil,
  },
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'typst',
  callback = function(args)
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc }) end

    map('n', '<leader>tp', '<cmd>TypstPreviewToggle<cr>', 'Toggle Typst Preview')
    map('n', '<leader>tc', '<cmd>TypstPreviewFollowCursorToggle<cr>', 'Toggle Follow Cursor')
  end,
})
