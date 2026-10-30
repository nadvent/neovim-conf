-- ============================================================================
-- 1. WHICH-KEY SETUP & GROUP DECLARATIONS
-- ============================================================================

vim.pack.add { 'https://github.com/folke/which-key.nvim' }

local wk = require 'which-key'

wk.setup {
  -- Dynamic delay: 0ms for plugins/custom menus, 200ms breathing room for chords
  delay = function(ctx) return ctx.plugin and 0 or 200 end,
  icons = {
    mappings = vim.g.have_nerd_font,
  },
  win = {
    no_overlap = false,
  },
}

wk.add {
  { '<leader>a', group = 'AI Assistant' },
  { '<leader>b', group = 'Buffers' },
  { '<leader>c', group = 'Code / LSP' },
  { '<leader>d', group = 'Debug' },
  { '<leader>f', group = 'Files / Find' },
  { '<leader>g', group = 'Git' },
  { '<leader>h', group = 'Git Hunks', mode = { 'n', 'v' } },
  { '<leader>p', group = 'Projects' },
  { '<leader>q', group = 'Session / Quit' },
  { '<leader>r', group = 'Run / Overseer' },
  { '<leader>s', group = 'Search' },
  { '<leader>t', group = 'Toggles' },
  { '<leader>u', group = 'UI / Editor Settings' },
  { '<leader>w', group = 'Windows' },
  { '<leader>x', group = 'Diagnostics / Lists' },
  { '<leader><Tab>', group = 'Tabs' },
  { 'g', group = 'Goto' },
  { 'gr', group = 'LSP Actions', mode = 'n' },
}

local map = vim.keymap.set
local builtin = setmetatable({}, {
  __index = function(_, k)
    return function(...)
      if _G.init_telescope then _G.init_telescope() end
      return require('telescope.builtin')[k](...)
    end
  end,
})

-- Helper to safely delete buffers without messing up window splits (using mini.bufremove)
local function bufdelete(force)
  local ok, mini_bufremove = pcall(require, 'mini.bufremove')
  if ok then
    mini_bufremove.delete(0, force or false)
  else
    vim.cmd(force and 'bdelete!' or 'bdelete')
  end
end

-- ============================================================================
-- 2. CORE EDITING & NAVIGATION
-- ============================================================================

-- Clear search highlighting
map('n', '<Esc>', '<cmd>nohlsearch<cr>', { desc = 'Clear Search Highlight' })

-- Move by screen line when no count is supplied; preserve normal counted moves
map({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = 'Down' })
map({ 'n', 'x' }, '<Down>', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = 'Down' })
map({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = 'Up' })
map({ 'n', 'x' }, '<Up>', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = 'Up' })

-- Center cursor when jumping half pages
map('n', '<C-d>', '<C-d>zz', { desc = 'Scroll Down and Center' })
map('n', '<C-u>', '<C-u>zz', { desc = 'Scroll Up and Center' })

-- Make n/N follow search direction and open folds
map('n', 'n', "'Nn'[v:searchforward].'zv'", { expr = true, desc = 'Next Search Result' })
map({ 'x', 'o' }, 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next Search Result' })
map('n', 'N', "'nN'[v:searchforward].'zv'", { expr = true, desc = 'Previous Search Result' })
map({ 'x', 'o' }, 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Previous Search Result' })

-- Create undo breakpoints after punctuation in insert mode
map('i', ',', ',<c-g>u', { desc = 'Comma undo breakpoint' })
map('i', '.', '.<c-g>u', { desc = 'Period undo breakpoint' })
map('i', ';', ';<c-g>u', { desc = 'Semicolon undo breakpoint' })

-- Save file from common modes
map({ 'i', 'x', 'n', 's' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save File' })

-- Paste in visual mode without replacing clipboard contents
map('x', 'p', 'P', { desc = 'Paste (preserve register)' })

-- Keyword lookup
map('n', '<leader>K', '<cmd>norm! K<cr>', { desc = 'Keyword Program' })

-- Keep visual selection after indenting
map('x', '<', '<gv', { desc = 'Indent Left and Reselect' })
map('x', '>', '>gv', { desc = 'Indent Right and Reselect' })

-- Add comment line above/below
map('n', 'gco', 'o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>', { desc = 'Add Comment Below' })
map('n', 'gcO', 'O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>', { desc = 'Add Comment Above' })

-- Move lines up/down
map('n', '<A-j>', "<cmd>execute 'move .+' . v:count1<cr>==", { desc = 'Move Line Down' })
map('n', '<A-k>', "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = 'Move Line Up' })
map('i', '<A-j>', '<esc><cmd>m .+1<cr>==gi', { desc = 'Move Line Down' })
map('i', '<A-k>', '<esc><cmd>m .-2<cr>==gi', { desc = 'Move Line Up' })
map('v', '<A-j>', ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = 'Move Selection Down' })
map('v', '<A-k>', ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = 'Move Selection Up' })

-- ============================================================================
-- 3. WINDOWS & SPLITS
-- ============================================================================

-- Window navigation (Normal & Terminal mode)
map({ 'n', 't' }, '<C-h>', '<cmd>wincmd h<cr>', { desc = 'Focus Left Window' })
map({ 'n', 't' }, '<C-j>', '<cmd>wincmd j<cr>', { desc = 'Focus Lower Window' })
map({ 'n', 't' }, '<C-k>', '<cmd>wincmd k<cr>', { desc = 'Focus Upper Window (Back to Code)' })
map({ 'n', 't' }, '<C-l>', '<cmd>wincmd l<cr>', { desc = 'Focus Right Window' })
map('t', '<C-w>', '<C-\\><C-n><C-w>', { desc = 'Window Navigation from Terminal' })
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit Terminal Mode to Normal Mode' })

-- Window resizing using arrow keys
map('n', '<C-Up>', '<cmd>resize +2<cr>', { desc = 'Increase Window Height' })
map('n', '<C-Down>', '<cmd>resize -2<cr>', { desc = 'Decrease Window Height' })
map('n', '<C-Left>', '<cmd>vertical resize -2<cr>', { desc = 'Decrease Window Width' })
map('n', '<C-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Increase Window Width' })

-- Window splits & deletion
map('n', '<leader>wd', '<C-W>c', { desc = 'Close Window' })
map('n', '<leader>-', '<C-W>s', { desc = 'Split Window Below' })
map('n', '<leader>|', '<C-W>v', { desc = 'Split Window Right' })
map('n', '<leader>w=', '<C-W>=', { desc = 'Equally Size Windows' })

-- Tabs
map('n', '<leader><Tab>l', '<cmd>tablast<cr>', { desc = 'Last Tab' })
map('n', '<leader><Tab>o', '<cmd>tabonly<cr>', { desc = 'Close Other Tabs' })
map('n', '<leader><Tab>f', '<cmd>tabfirst<cr>', { desc = 'First Tab' })
map('n', '<leader><Tab><Tab>', '<cmd>tabnew<cr>', { desc = 'New Tab' })
map('n', '<leader><Tab>]', '<cmd>tabnext<cr>', { desc = 'Next Tab' })
map('n', '<leader><Tab>d', '<cmd>tabclose<cr>', { desc = 'Close Tab' })
map('n', '<leader><Tab>[', '<cmd>tabprevious<cr>', { desc = 'Previous Tab' })

-- Terminal mode escape
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit Terminal Mode' })

-- ============================================================================
-- 4. BUFFERS & FILES
-- ============================================================================

map('n', '<leader>fn', '<cmd>enew<cr>', { desc = 'New File' })
map('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
map('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
map('n', '[b', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
map('n', ']b', '<cmd>bnext<cr>', { desc = 'Next Buffer' })

map('n', '<leader>bb', builtin.buffers, { desc = 'List Buffers (Telescope)' })
map('n', '<leader>,', builtin.buffers, { desc = 'Switch Buffer' })
map('n', '<leader>`', '<cmd>e #<cr>', { desc = 'Switch to Alternate Buffer' })
map('n', '<leader>bd', function() bufdelete(false) end, { desc = 'Delete Buffer' })
map('n', '<leader>bD', function() bufdelete(true) end, { desc = 'Delete Buffer (Force)' })

-- File Explorers (Mini.files & Yazi)
map('n', '<leader>e', function()
  if _G.BufferlineToggleMiniFiles then
    _G.BufferlineToggleMiniFiles()
  else
    if _G.init_mini_files then _G.init_mini_files() end
    local mf = require 'mini.files'
    if not mf.close() then
      local bufname = vim.api.nvim_buf_get_name(0)
      if bufname ~= '' and vim.uv.fs_stat(bufname) then
        mf.open(bufname, true)
      else
        mf.open(vim.fn.getcwd(), true)
      end
    end
  end
end, { desc = 'Toggle File Explorer (Mini.files)' })
map({ 'n', 'v' }, '<leader>ff', '<cmd>Yazi<cr>', { desc = 'Open Yazi at Current File' })
map({ 'n', 'v' }, '<leader>fF', '<cmd>Yazi cwd<cr>', { desc = 'Open Yazi at CWD' })

-- Project Management (<leader>p)
map('n', '<leader>pp', function() Snacks.picker.projects() end, { desc = 'Find Projects' })
map('n', '<leader>fp', function() Snacks.picker.projects() end, { desc = 'Find Projects' })
map({ 'n', 't' }, '<leader>pt', function() Snacks.terminal.toggle() end, { desc = 'Toggle Project Terminal (Bottom Split)' })
map({ 'n', 't' }, '<C-/>', function() Snacks.terminal.toggle() end, { desc = 'Toggle Project Terminal' })
map({ 'n', 't' }, '<C-_>', function() Snacks.terminal.toggle() end, { desc = 'Toggle Project Terminal' })
map('n', '<leader>pn', function() Snacks.scratch() end, { desc = 'Toggle Project Scratchpad' })
map('n', '<leader>pg', function()
  Snacks.scratch { file = vim.fn.expand '~/Documents/Obsidian Vault/TODO.md', name = 'Global Tasks', ft = 'markdown' }
end, { desc = 'Toggle Global Tasks' })
map('n', '<leader>pd', '<cmd>Yazi cwd<cr>', { desc = 'Open Yazi at Project Root' })
map('n', '<leader>ps', function() require('persistence').load() end, { desc = 'Restore Project Session' })

-- ============================================================================
-- 5. SEARCH (TELESCOPE)
-- ============================================================================

map('n', '<leader><space>', builtin.find_files, { desc = 'Find Files (Root)' })
map('n', '<leader>sf', builtin.find_files, { desc = 'Search Files' })
map('n', '<leader>sh', builtin.help_tags, { desc = 'Search Help' })
map('n', '<leader>sk', builtin.keymaps, { desc = 'Search Keymaps' })
map('n', '<leader>ss', builtin.builtin, { desc = 'Search Telescope Pickers' })
map({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = 'Search Current Word' })
map('n', '<leader>sg', builtin.live_grep, { desc = 'Search by Grep' })
map('n', '<leader>st', '<cmd>TodoTelescope<cr>', { desc = 'Search TODOs / Fixes' })
map('n', '<leader>sb', '<cmd>TodoTelescope keywords=FIX,FIXME,BUG,ISSUE<cr>', { desc = 'Search Bugs / Fixes' })
map('n', '<leader>sd', builtin.diagnostics, { desc = 'Search Diagnostics' })
map('n', '<leader>sr', builtin.resume, { desc = 'Resume Search' })
map('n', '<leader>s.', builtin.oldfiles, { desc = 'Search Recent Files' })
map('n', '<leader>sc', builtin.commands, { desc = 'Search Commands' })

map(
  'n',
  '<leader>/',
  function()
    builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
      winblend = 10,
      previewer = false,
    })
  end,
  { desc = 'Search Current Buffer' }
)

map(
  'n',
  '<leader>s/',
  function()
    builtin.live_grep {
      grep_open_files = true,
      prompt_title = 'Live Grep in Open Files',
    }
  end,
  { desc = 'Search Open Files' }
)

map('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config', follow = true } end, { desc = 'Search Neovim Config' })

-- ============================================================================
-- 6. CODE, NAVIGATION & AI
-- ============================================================================

-- Flash Jump
map({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, { desc = 'Flash' })
map({ 'n', 'x', 'o' }, 'S', function() require('flash').treesitter() end, { desc = 'Flash Treesitter' })
map('o', 'r', function() require('flash').remote() end, { desc = 'Remote Flash' })
map({ 'o', 'x' }, 'R', function() require('flash').treesitter_search() end, { desc = 'Treesitter Search' })
map('c', '<c-s>', function() require('flash').toggle() end, { desc = 'Toggle Flash Search' })

-- LSP Navigation via Telescope
map('n', 'gd', builtin.lsp_definitions, { desc = 'Goto Definition' })
map('n', 'grr', builtin.lsp_references, { desc = 'Goto References' })
map('n', 'gri', builtin.lsp_implementations, { desc = 'Goto Implementations' })
map('n', 'grt', builtin.lsp_type_definitions, { desc = 'Goto Type Definition' })
map('n', 'gO', builtin.lsp_document_symbols, { desc = 'Document Symbols' })
map('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { desc = 'Workspace Symbols' })

-- Trouble Code Views
map('n', '<leader>cs', '<cmd>Trouble symbols toggle focus=false<cr>', { desc = 'Toggle Symbols (Trouble)' })
map('n', '<leader>cl', '<cmd>Trouble lsp toggle focus=false win.position=right<cr>', { desc = 'LSP Definitions / References (Trouble)' })

-- Formatting
map({ 'n', 'v' }, '<leader>cf', function() require('conform').format { async = true, lsp_format = 'fallback' } end, { desc = 'Format Buffer' })

-- Sidekick AI
map({ 'n', 't', 'i', 'x' }, '<C-.>', function() require('sidekick.cli').focus() end, { desc = 'Sidekick: Focus' })
map('n', '<leader>aa', function() require('sidekick.cli').toggle() end, { desc = 'Sidekick: Toggle CLI' })
map('n', '<leader>as', function() require('sidekick.cli').select() end, { desc = 'Sidekick: Select CLI' })
map('n', '<leader>ad', function() require('sidekick.cli').close() end, { desc = 'Sidekick: Detach Session' })
map({ 'x', 'n' }, '<leader>at', function() require('sidekick.cli').send { msg = '{this}' } end, { desc = 'Sidekick: Send Context' })
map('n', '<leader>af', function() require('sidekick.cli').send { msg = '{file}' } end, { desc = 'Sidekick: Send File' })
map('x', '<leader>av', function() require('sidekick.cli').send { msg = '{selection}' } end, { desc = 'Sidekick: Send Selection' })
map({ 'n', 'x' }, '<leader>ap', function() require('sidekick.cli').prompt() end, { desc = 'Sidekick: Select Prompt' })
map('n', '<leader>ac', function() require('sidekick.cli').toggle { name = 'gemini', focus = true } end, { desc = 'Sidekick: Toggle Gemini' })

-- ============================================================================
-- 7. DIAGNOSTICS & LISTS
-- ============================================================================

vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },
  virtual_text = true,
  virtual_lines = false,
}

local function diagnostic_goto(next, severity)
  return function()
    vim.diagnostic.jump {
      count = (next and 1 or -1) * vim.v.count1,
      severity = severity and vim.diagnostic.severity[severity] or nil,
      float = true,
    }
  end
end

map('n', '<leader>cd', vim.diagnostic.open_float, { desc = 'Line Diagnostics' })
map('n', '<leader>xd', vim.diagnostic.open_float, { desc = 'Line Diagnostics' })
map('n', '<leader>xD', vim.diagnostic.setloclist, { desc = 'Diagnostics to Location List' })

map('n', ']d', diagnostic_goto(true), { desc = 'Next Diagnostic' })
map('n', '[d', diagnostic_goto(false), { desc = 'Prev Diagnostic' })
map('n', ']e', diagnostic_goto(true, 'ERROR'), { desc = 'Next Error' })
map('n', '[e', diagnostic_goto(false, 'ERROR'), { desc = 'Prev Error' })
map('n', ']w', diagnostic_goto(true, 'WARN'), { desc = 'Next Warning' })
map('n', '[w', diagnostic_goto(false, 'WARN'), { desc = 'Prev Warning' })

-- In-code TODO / Bug navigation jumps
map('n', ']t', function() require('todo-comments').jump_next() end, { desc = 'Next TODO / Bug' })
map('n', '[t', function() require('todo-comments').jump_prev() end, { desc = 'Previous TODO / Bug' })

-- Quickfix & Location list toggles
map('n', '<leader>xl', function()
  local is_open = vim.fn.getloclist(0, { winid = 0 }).winid ~= 0
  local ok, err = pcall(is_open and vim.cmd.lclose or vim.cmd.lopen)
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end, { desc = 'Toggle Location List' })

map('n', '<leader>xq', function()
  local is_open = vim.fn.getqflist({ winid = 0 }).winid ~= 0
  local ok, err = pcall(is_open and vim.cmd.cclose or vim.cmd.copen)
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end, { desc = 'Toggle Quickfix List' })

map('n', '[q', vim.cmd.cprev, { desc = 'Prev Quickfix Item' })
map('n', ']q', vim.cmd.cnext, { desc = 'Next Quickfix Item' })
map('n', '[l', vim.cmd.lprev, { desc = 'Prev Location Item' })
map('n', ']l', vim.cmd.lnext, { desc = 'Next Location Item' })

-- Trouble diagnostic & task views
map('n', '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', { desc = 'Toggle Diagnostics (Trouble)' })
map('n', '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', { desc = 'Buffer Diagnostics (Trouble)' })
map('n', '<leader>xt', '<cmd>Trouble todo toggle<cr>', { desc = 'Toggle TODOs (Trouble)' })
map('n', '<leader>xT', '<cmd>Trouble todo toggle filter.buf=0<cr>', { desc = 'Buffer TODOs (Trouble)' })
map('n', '<leader>xL', '<cmd>Trouble loclist toggle<cr>', { desc = 'Location List (Trouble)' })
map('n', '<leader>xQ', '<cmd>Trouble qflist toggle<cr>', { desc = 'Quickfix List (Trouble)' })

-- Scratchpads
map('n', '<leader>.', function() Snacks.scratch() end, { desc = 'Toggle Project Scratchpad' })
map('n', '<leader>S', function() Snacks.scratch.select() end, { desc = 'Select Scratchpad' })

-- ============================================================================
-- 8. DEBUGGING (DAP) & RUNNER (OVERSEER)
-- ============================================================================

local function dap() return (_G.load_dap and _G.load_dap()) or require 'dap' end

map('n', '<leader>dc', function() dap().continue() end, { desc = 'Start / Continue' })
map('n', '<leader>di', function() dap().step_into() end, { desc = 'Step Into' })
map('n', '<leader>do', function() dap().step_over() end, { desc = 'Step Over' })
map('n', '<leader>dO', function() dap().step_out() end, { desc = 'Step Out' })
map('n', '<leader>db', function() dap().toggle_breakpoint() end, { desc = 'Toggle Breakpoint' })
map('n', '<leader>dB', function() dap().set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, { desc = 'Conditional Breakpoint' })
map('n', '<leader>du', function() require('dapui').toggle() end, { desc = 'Toggle Debug UI' })

-- Function key aliases
map('n', '<F5>', function() dap().continue() end, { desc = 'Debug: Continue' })
map('n', '<F1>', function() dap().step_into() end, { desc = 'Debug: Step Into' })
map('n', '<F2>', function() dap().step_over() end, { desc = 'Debug: Step Over' })
map('n', '<F3>', function() dap().step_out() end, { desc = 'Debug: Step Out' })
map('n', '<F7>', function() require('dapui').toggle() end, { desc = 'Debug: Toggle UI' })

-- Overseer Task Runner
map('n', '<leader>rr', '<cmd>OverseerRun<cr>', { desc = 'Run Task' })
map('n', '<leader>rt', '<cmd>OverseerToggle<cr>', { desc = 'Toggle Task Runner' })
map('n', '<leader>ra', '<cmd>OverseerTaskAction<cr>', { desc = 'Task Action' })
map('n', '<leader>or', function()
  local overseer = require 'overseer'
  local tasks = overseer.list_tasks {
    status = overseer.STATUS.SUCCESS,
    sort = function(a, b)
      -- Most recently updated/started first
      return a.id > b.id
    end,
  }

  if #tasks > 0 then
    -- Rerun the most recent successful task
    tasks[1]:restart()
  else
    vim.notify('No previously successful task found', vim.log.levels.WARN)
  end
end, { desc = 'Overseer: Rerun last successful task' })
-- ============================================================================
-- 9. GIT INTEGRATION
-- ============================================================================

-- LazyGit (via lazygit.nvim)
map('n', '<leader>gg', '<cmd>LazyGit<cr>', { desc = 'Open LazyGit' })

-- Git log & status via Telescope
map('n', '<leader>gl', builtin.git_commits, { desc = 'Git Commits (Log)' })
map('n', '<leader>gL', builtin.git_bcommits, { desc = 'Git Buffer Commits' })
map('n', '<leader>gs', builtin.git_status, { desc = 'Git Status' })
map('n', '<leader>gb', builtin.git_branches, { desc = 'Git Branches' })

-- GitHub Issues & PRs (Snacks.gh)
map('n', '<leader>gi', function() Snacks.picker.gh_issue() end, { desc = 'GitHub Issues (Open)' })
map('n', '<leader>gI', function() Snacks.picker.gh_issue { state = 'all' } end, { desc = 'GitHub Issues (All)' })
map('n', '<leader>gp', function() Snacks.picker.gh_pr() end, { desc = 'GitHub Pull Requests (Open)' })
map('n', '<leader>gP', function() Snacks.picker.gh_pr { state = 'all' } end, { desc = 'GitHub Pull Requests (All)' })

-- ============================================================================
-- 10. UI & EDITOR TOGGLES (<leader>u)
-- ============================================================================

map('n', '<leader>ur', '<cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><cr>', { desc = 'Redraw / Clear Highlights' })
map('n', '<leader>ui', vim.show_pos, { desc = 'Inspect Position' })
map('n', '<leader>uI', function()
  vim.treesitter.inspect_tree()
  vim.api.nvim_input 'I'
end, { desc = 'Inspect Treesitter Tree' })
map('n', '<leader>uP', '<cmd>Pack<cr>', { desc = 'Plugin / Pack UI' })
map('n', '<leader>uz', function() Snacks.zen() end, { desc = 'Toggle Zen Mode' })
map('n', '<leader>up', function() require('core.noctalia').toggle_profile() end, { desc = 'Toggle Theme Profile (Noctalia/Standard)' })

-- LazyVim-style toggles
map('n', '<leader>uw', function()
  vim.wo.wrap = not vim.wo.wrap
  vim.notify('Wrap: ' .. (vim.wo.wrap and 'ON' or 'OFF'), vim.log.levels.INFO)
end, { desc = 'Toggle Line Wrap' })

map('n', '<leader>us', function()
  vim.wo.spell = not vim.wo.spell
  vim.notify('Spell: ' .. (vim.wo.spell and 'ON' or 'OFF'), vim.log.levels.INFO)
end, { desc = 'Toggle Spell Check' })

map('n', '<leader>ul', function()
  vim.wo.relativenumber = not vim.wo.relativenumber
  vim.notify('Relative Number: ' .. (vim.wo.relativenumber and 'ON' or 'OFF'), vim.log.levels.INFO)
end, { desc = 'Toggle Relative Numbers' })

map('n', '<leader>ud', function()
  local enabled = not vim.diagnostic.is_enabled()
  vim.diagnostic.enable(enabled)
  vim.notify('Diagnostics: ' .. (enabled and 'ON' or 'OFF'), vim.log.levels.INFO)
end, { desc = 'Toggle Diagnostics' })

map('n', '<leader>uc', function()
  local next_val = vim.wo.conceallevel > 0 and 0 or 2
  vim.wo.conceallevel = next_val
  vim.notify('Conceallevel: ' .. next_val, vim.log.levels.INFO)
end, { desc = 'Toggle Conceal Level' })

-- ============================================================================
-- 11. SESSIONS & QUITTING
-- ============================================================================

map('n', '<leader>qs', function() require('persistence').load() end, { desc = 'Restore Session (CWD)' })
map('n', '<leader>qS', function() require('persistence').select() end, { desc = 'Select Session' })
map('n', '<leader>ql', function() require('persistence').load { last = true } end, { desc = 'Restore Last Session' })
map('n', '<leader>qd', function() require('persistence').stop() end, { desc = 'Stop Session Saving' })
map('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit All' })
