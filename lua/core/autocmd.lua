local util = require 'core.util'

-- Trigger autoread when files change externally or when returning to buffers
vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'CursorHoldI', 'FocusGained' }, {
  group = util.augroup 'autoread_checktime',
  callback = function()
    if vim.fn.mode() ~= 'c' then vim.cmd 'checktime' end
  end,
})

-- Restore cursor to last known position when opening a file
vim.api.nvim_create_autocmd('BufReadPost', {
  group = util.augroup 'restore_cursor',
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= lcount then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
  end,
})

-- Resize splits equally when terminal window resizes
vim.api.nvim_create_autocmd('VimResized', {
  group = util.augroup 'resize_splits',
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
  end,
})

-- Close transient utility filetypes with <q>
vim.api.nvim_create_autocmd('FileType', {
  group = util.augroup 'close_with_q',
  pattern = {
    'PlenaryTestPopup',
    'checkhealth',
    'dap-float',
    'dbout',
    'gitsigns-blame',
    'grug-far',
    'help',
    'lspinfo',
    'neotest-output',
    'neotest-output-panel',
    'neotest-summary',
    'notify',
    'qf',
    'spectre_panel',
    'startuptime',
    'tsplayground',
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(event.buf) then return end
      vim.keymap.set('n', 'q', function()
        vim.cmd 'close'
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, {
        buffer = event.buf,
        silent = true,
        desc = 'Quit buffer',
      })
    end)
  end,
})

-- Exclude inline man pages from buffer list
vim.api.nvim_create_autocmd('FileType', {
  group = util.augroup 'man_unlisted',
  pattern = { 'man' },
  callback = function(event) vim.bo[event.buf].buflisted = false end,
})

-- Keep non-file / UI windows and huge files out of expr folding without breaking normal files opened in the same window
vim.api.nvim_create_autocmd({ 'BufWinEnter', 'FileType' }, {
  group = util.augroup 'nonfile_foldmethod',
  callback = function(args)
    if not vim.api.nvim_buf_is_valid(args.buf) then return end
    local is_nonfile = vim.bo[args.buf].buftype ~= '' or vim.bo[args.buf].filetype == 'bigfile'
    for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
      if vim.api.nvim_win_is_valid(win) then
        if is_nonfile then
          if vim.wo[win].foldmethod == 'expr' then
            vim.w[win]._auto_manual_fold = true
            vim.wo[win].foldmethod = 'manual'
          end
        elseif vim.w[win]._auto_manual_fold then
          vim.w[win]._auto_manual_fold = nil
          vim.wo[win].foldmethod = 'expr'
          vim.wo[win].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        end
      end
    end
  end,
})

-- Enable line wrapping and spell checking in prose filetypes
vim.api.nvim_create_autocmd('FileType', {
  group = util.augroup 'wrap_spell',
  pattern = { 'text', 'plaintex', 'typst', 'gitcommit', 'markdown' },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- Show literal quotes in JSON files
vim.api.nvim_create_autocmd('FileType', {
  group = util.augroup 'json_conceal',
  pattern = { 'json', 'jsonc', 'json5' },
  callback = function() vim.opt_local.conceallevel = 0 end,
})

-- Auto-create missing parent directories before saving
vim.api.nvim_create_autocmd('BufWritePre', {
  group = util.augroup 'auto_create_dir',
  callback = function(event)
    if event.match:match '^%w%w+:[\\/][\\/]' then return end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
  end,
})

-- Auto-setup Google Sheets project integration when inside ~/Projects/Google
vim.api.nvim_create_autocmd({ 'VimEnter', 'DirChanged', 'BufEnter' }, {
  group = util.augroup 'gspread_project',
  callback = function()
    if not util.in_gspread(false) then return end
    local ok, gspread = pcall(require, 'plugins.opt.gspread')
    if ok and gspread and gspread.setup then gspread.setup() end
  end,
})

-- Auto-setup LeetCode environment and suppress AI suggestions inside ~/Projects/leetCode
local function disable_ai_assistants()
  pcall(function()
    if package.loaded['copilot.command'] or package.loaded['copilot'] then require('copilot.command').disable() end
  end)
  pcall(vim.lsp.enable, 'copilot', false)
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.name:lower():find 'copilot' then client:stop() end
  end
  pcall(function()
    if package.loaded['sidekick.nes'] or package.loaded['sidekick'] then require('sidekick.nes').disable() end
  end)
end

local function check_leetcode_env()
  if not util.in_leetcode() then return end
  disable_ai_assistants()
  local ok, lc = pcall(require, 'plugins.opt.leetcode')
  if ok and lc and lc.setup then lc.setup() end
end

if util.in_leetcode() then pcall(function() require('plugins.opt.leetcode').setup() end) end

vim.api.nvim_create_autocmd({ 'VimEnter', 'DirChanged', 'BufEnter' }, {
  group = util.augroup 'leetcode_project',
  callback = check_leetcode_env,
})

vim.api.nvim_create_autocmd('VimEnter', {
  group = util.augroup 'leetcode_dashboard',
  once = true,
  callback = function()
    if vim.fn.argc(-1) ~= 0 or not util.in_leetcode() then return end
    vim.schedule(function()
      if vim.api.nvim_buf_get_name(0) == '' and vim.fn.exists ':Leet' == 2 then pcall(vim.cmd, 'Leet') end
    end)
  end,
})
