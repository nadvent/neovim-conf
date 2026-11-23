local util = require 'core.util'

local map = util.map

-- ============================================================================
-- 1. WHICH-KEY GROUP DECLARATIONS
-- ============================================================================

local ok_wk, wk = pcall(require, 'which-key')
if ok_wk then
  wk.add {
    { '<leader>a', group = 'AI Assistant' },
    { '<leader>b', group = 'Buffers' },
    { '<leader>c', group = 'Code / LSP' },
    { '<leader>d', group = 'Debug' },
    { '<leader>f', group = 'Files / Find' },
    { '<leader>g', group = 'Git' },
    { '<leader>G', group = 'Google Sheets' },
    { '<leader>h', group = 'Git Hunks', mode = { 'n', 'v' } },
    { '<leader>l', group = 'Language / LeetCode' },
    { '<leader>m', group = 'Markdown' },
    { '<leader>p', group = 'Projects' },
    { '<leader>q', group = 'Session / Quit' },
    { '<leader>r', group = 'Run / Overseer' },
    { '<leader>s', group = 'Search' },
    { '<leader>t', group = 'Tasks / Bugs / Time', mode = { 'n', 'v' } },
    { '<leader>u', group = 'UI / Editor Settings' },
    { '<leader>w', group = 'Windows' },
    { '<leader>x', group = 'Diagnostics / Lists' },
    { '<leader><Tab>', group = 'Tabs' },
    { 'g', group = 'Goto' },
    { 'gs', group = 'Surround', mode = { 'n', 'x' } },
    { 'gr', group = 'LSP Actions', mode = 'n' },
  }
end

local function pick(fn_name, opts)
  return function()
    local ok, mini_pick = pcall(require, 'mini.pick')
    if ok and mini_pick.builtin[fn_name] then mini_pick.builtin[fn_name](opts) end
  end
end

local function extra(fn_name, opts)
  return function()
    local ok, mini_extra = pcall(require, 'mini.extra')
    if ok and mini_extra.pickers[fn_name] then mini_extra.pickers[fn_name](opts) end
  end
end

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

-- Clear search highlighting, multicursors, and diagnostic float
map('n', '<Esc>', function()
  vim.cmd.nohlsearch()
  local mc_ns = vim.api.nvim_create_namespace 'nvim.multicursor'
  vim.api.nvim_buf_clear_namespace(0, mc_ns, 0, -1)
  pcall(function() require('core.diagnostics').close() end)
end, 'Clear Search Highlight, Multicursors & Diagnostics')

-- Move by screen line when no count is supplied; preserve normal counted moves
map({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = 'Down' })
map({ 'n', 'x' }, '<Down>', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = 'Down' })
map({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = 'Up' })
map({ 'n', 'x' }, '<Up>', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = 'Up' })

-- Center cursor when jumping half pages
map('n', '<C-d>', '<C-d>zz', 'Scroll Down and Center')
map('n', '<C-u>', '<C-u>zz', 'Scroll Up and Center')

-- Make n/N follow search direction and open folds
map('n', 'n', "'Nn'[v:searchforward].'zv'", { expr = true, desc = 'Next Search Result' })
map({ 'x', 'o' }, 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next Search Result' })
map('n', 'N', "'nN'[v:searchforward].'zv'", { expr = true, desc = 'Previous Search Result' })
map({ 'x', 'o' }, 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Previous Search Result' })

-- Create undo breakpoints after punctuation in insert mode
map('i', ',', ',<c-g>u', 'Comma undo breakpoint')
map('i', '.', '.<c-g>u', 'Period undo breakpoint')
map('i', ';', ';<c-g>u', 'Semicolon undo breakpoint')

-- Save file from common modes
map({ 'i', 'x', 'n', 's' }, '<C-s>', '<cmd>w<cr><esc>', 'Save File')

-- Keyword lookup
map('n', '<leader>K', '<cmd>norm! K<cr>', 'Keyword Program')

-- Keep visual selection after indenting
map('x', '<', '<gv', 'Indent Left and Reselect')
map('x', '>', '>gv', 'Indent Right and Reselect')

-- Hybrid folding: preserve existing Treesitter folds when creating manual zf folds
map({ 'n', 'x' }, 'zf', function()
  if vim.wo.foldmethod ~= 'manual' then
    vim.wo.foldmethod = 'manual'
    vim.schedule(function() vim.notify('Folding: Manual (existing folds preserved)', vim.log.levels.INFO) end)
  end
  return 'zf'
end, { expr = true, desc = 'Create Manual Fold (Preserves TS Folds)' })

-- Add comment line above/below
map('n', 'gco', 'o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>', 'Add Comment Below')
map('n', 'gcO', 'O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>', 'Add Comment Above')

-- Move lines up/down
map('n', '<A-j>', "<cmd>execute 'move .+' . v:count1<cr>==", 'Move Line Down')
map('n', '<A-k>', "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", 'Move Line Up')
map('i', '<A-j>', '<esc><cmd>m .+1<cr>==gi', 'Move Line Down')
map('i', '<A-k>', '<esc><cmd>m .-2<cr>==gi', 'Move Line Up')
map('v', '<A-j>', ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", 'Move Selection Down')
map('v', '<A-k>', ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", 'Move Selection Up')

-- ============================================================================
-- 3. WINDOWS, SPLITS & TERMINAL
-- ============================================================================

map({ 'n', 't' }, '<C-h>', '<cmd>wincmd h<cr>', 'Focus Left Window')
map({ 'n', 't' }, '<C-j>', '<cmd>wincmd j<cr>', 'Focus Lower Window')
map({ 'n', 't' }, '<C-k>', '<cmd>wincmd k<cr>', 'Focus Upper Window (Back to Code)')
map({ 'n', 't' }, '<C-l>', '<cmd>wincmd l<cr>', 'Focus Right Window')
map('t', '<C-w>', '<C-\\><C-n><C-w>', 'Window Navigation from Terminal')

map('n', '<C-Up>', '<cmd>resize +2<cr>', 'Increase Window Height')
map('n', '<C-Down>', '<cmd>resize -2<cr>', 'Decrease Window Height')
map('n', '<C-Left>', '<cmd>vertical resize -2<cr>', 'Decrease Window Width')
map('n', '<C-Right>', '<cmd>vertical resize +2<cr>', 'Increase Window Width')

map('n', '<leader>wd', '<C-W>c', 'Close Window')
map('n', '<leader>-', '<C-W>s', 'Split Window Below')
map('n', '<leader>|', '<C-W>v', 'Split Window Right')
map('n', '<leader>w=', '<C-W>=', 'Equally Size Windows')

map('n', '<leader><Tab>l', '<cmd>tablast<cr>', 'Last Tab')
map('n', '<leader><Tab>o', '<cmd>tabonly<cr>', 'Close Other Tabs')
map('n', '<leader><Tab>f', '<cmd>tabfirst<cr>', 'First Tab')
map('n', '<leader><Tab><Tab>', '<cmd>tabnew<cr>', 'New Tab')
map('n', '<leader><Tab>]', '<cmd>tabnext<cr>', 'Next Tab')
map('n', '<leader><Tab>d', '<cmd>tabclose<cr>', 'Close Tab')
map('n', '<leader><Tab>[', '<cmd>tabprevious<cr>', 'Previous Tab')

-- ============================================================================
-- 4. BUFFERS, FILES & PROJECTS
-- ============================================================================

map('n', '<leader>fn', '<cmd>enew<cr>', 'New File')
map('n', '<S-h>', '<cmd>bprevious<cr>', 'Prev Buffer')
map('n', '<S-l>', '<cmd>bnext<cr>', 'Next Buffer')
map('n', '[b', '<cmd>bprevious<cr>', 'Prev Buffer')
map('n', ']b', '<cmd>bnext<cr>', 'Next Buffer')

map('n', '<leader>bb', pick 'buffers', 'List Buffers (Mini.pick)')
map('n', '<leader>,', pick 'buffers', 'Switch Buffer')
map('n', '<leader>`', '<cmd>e #<cr>', 'Switch to Alternate Buffer')
map('n', '<leader>bd', function() bufdelete(false) end, 'Delete Buffer')
map('n', '<leader>bD', function() bufdelete(true) end, 'Delete Buffer (Force)')

map('n', '<leader>e', function() require('plugins.ux').toggle_files() end, 'Mini.Files')
map({ 'n', 'v' }, '<leader>ff', '<cmd>Yazi<cr>', 'Open Yazi at Current File')
map({ 'n', 'v' }, '<leader>fF', '<cmd>Yazi cwd<cr>', 'Open Yazi at CWD')

map('n', '<leader>pp', function() require('mini.pick').registry.projects() end, 'Find Projects')
map('n', '<leader>fp', function() require('mini.pick').registry.projects() end, 'Find Projects')
map('n', '<leader>pt', function() Snacks.terminal.toggle() end, 'Toggle Project Terminal (Bottom Split)')
map({ 'n', 't' }, '<C-/>', function() Snacks.terminal.toggle() end, 'Toggle Project Terminal')
map({ 'n', 't' }, '<C-_>', function() Snacks.terminal.toggle() end, 'Toggle Project Terminal')
map('n', '<leader>pn', function() Snacks.scratch() end, 'Toggle Project Scratchpad')
map('n', '<leader>pd', '<cmd>Yazi cwd<cr>', 'Open Yazi at Project Root')
map('n', '<leader>ps', function() pcall(function() require('mini.sessions').read() end) end, 'Restore Project Session')

-- ============================================================================
-- 5. SEARCH (MINI.PICK)
-- ============================================================================

map('n', '<leader><space>', pick 'files', 'Find Files (Root)')
map('n', '<leader>sf', pick 'files', 'Search Files')
map('n', '<leader>sh', pick 'help', 'Search Help')
map('n', '<leader>sk', extra 'keymaps', 'Search Keymaps')
map('n', '<leader>ss', pick 'cli', 'Search Pickers')
map({ 'n', 'v' }, '<leader>sw', function() require('mini.pick').builtin.grep { pattern = vim.fn.expand '<cword>' } end, 'Search Current Word')
map('n', '<leader>sg', pick 'grep_live', 'Search by Grep')
map('n', '<leader>st', function() require('mini.pick').registry.todo() end, 'Search TODOs / Fixes')
map('n', '<leader>sb', function() require('mini.pick').registry.todo { keywords = 'FIX,FIXME,BUG,ISSUE' } end, 'Search Bugs / Fixes')
map('n', '<leader>sd', extra 'diagnostic', 'Search Diagnostics')
map('n', '<leader>sr', pick 'resume', 'Resume Search')
map('n', '<leader>s.', extra 'oldfiles', 'Search Recent Files')
map('n', '<leader>sc', extra 'commands', 'Search Commands')
map('n', '<leader>sj', extra('list', { scope = 'jump' }), 'Search Jumplist')
map('n', '<leader>s;', extra('list', { scope = 'change' }), 'Search Changelist (Recent Edits)')

map('n', '<leader>/', extra 'buf_lines', 'Search Current Buffer')
map('n', '<leader>s/', pick 'grep_live', 'Search Open Files')
map('n', '<leader>sn', function() require('mini.pick').builtin.files({}, { source = { cwd = vim.fn.stdpath 'config' } }) end, 'Search Neovim Config')

-- ============================================================================
-- 6. CODE, NAVIGATION & AI
-- ============================================================================

map({ 'n', 'x', 'o' }, 's', function() require('flash').jump() end, 'Flash')
map({ 'n', 'x', 'o' }, 'S', function() require('flash').treesitter() end, 'Flash Treesitter')
map('o', 'r', function() require('flash').remote() end, 'Remote Flash')
map({ 'o', 'x' }, 'R', function() require('flash').treesitter_search() end, 'Treesitter Search')
map('c', '<c-s>', function() require('flash').toggle() end, 'Toggle Flash Search')

map('n', 'gd', extra('lsp', { scope = 'definition' }), 'Goto Definition')
map('n', 'gD', function() require('lspeek').peek_definition() end, 'Peek Definition (lspeek)')
map('n', 'gT', function() require('lspeek').peek_type_definition() end, 'Peek Type Definition (lspeek)')
map('n', 'grr', extra('lsp', { scope = 'references' }), 'Goto References')
map('n', 'gri', extra('lsp', { scope = 'implementation' }), 'Goto Implementations')
map('n', 'grt', extra('lsp', { scope = 'type_definition' }), 'Goto Type Definition')
map('n', 'gO', extra('lsp', { scope = 'document_symbol' }), 'Document Symbols')
map('n', 'gW', extra('lsp', { scope = 'workspace_symbol' }), 'Workspace Symbols')

map('n', '<leader>cs', extra('lsp', { scope = 'document_symbol' }), 'Document Symbols')
map('n', '<leader>cl', extra('lsp', { scope = 'references' }), 'LSP References')
map('n', '<leader>ci', vim.lsp.buf.incoming_calls, 'Call Hierarchy (Incoming)')
map('n', '<leader>co', vim.lsp.buf.outgoing_calls, 'Call Hierarchy (Outgoing)')
map({ 'n', 'v' }, '<leader>cf', function() require('conform').format { async = true, lsp_format = 'fallback' } end, 'Format Buffer')

map({ 'n', 't', 'i', 'x' }, '<C-.>', function() require('sidekick.cli').focus() end, 'Sidekick: Focus')
map('n', '<leader>aa', function() require('sidekick.cli').toggle() end, 'Sidekick: Toggle CLI')
map('n', '<leader>as', function() require('sidekick.cli').select() end, 'Sidekick: Select CLI')
map('n', '<leader>ad', function() require('sidekick.cli').close() end, 'Sidekick: Detach Session')
map({ 'x', 'n' }, '<leader>at', function() require('sidekick.cli').send { msg = '{this}' } end, 'Sidekick: Send Context')
map('n', '<leader>af', function() require('sidekick.cli').send { msg = '{file}' } end, 'Sidekick: Send File')
map('x', '<leader>av', function() require('sidekick.cli').send { msg = '{selection}' } end, 'Sidekick: Send Selection')
map({ 'n', 'x' }, '<leader>ap', function() require('sidekick.cli').prompt() end, 'Sidekick: Select Prompt')
map('n', '<leader>ac', function() require('sidekick.cli').toggle { name = 'antigravity', focus = true } end, 'Sidekick: Toggle Antigravity')

-- ============================================================================
-- 7. DIAGNOSTICS, AST MOTIONS & LISTS
-- ============================================================================

local function diag_hover(opts)
  local ok, fancy_diag = pcall(require, 'core.diagnostics')
  if ok and fancy_diag.hover then
    fancy_diag.hover(nil, opts)
  else
    vim.diagnostic.open_float()
  end
end

local function diagnostic_goto(next, severity)
  return function()
    vim.diagnostic.jump {
      count = (next and 1 or -1) * vim.v.count1,
      severity = severity and vim.diagnostic.severity[severity] or nil,
      float = false,
    }
    diag_hover { refresh = true }
  end
end

map('n', '<leader>cd', function() diag_hover() end, 'Line Diagnostics (Fancy)')
map('n', '<leader>xd', function() diag_hover() end, 'Line Diagnostics (Fancy)')
map('n', 'gl', function() diag_hover() end, 'Line Diagnostics (Fancy)')
map('n', '<leader>xD', vim.diagnostic.setloclist, 'Diagnostics to Location List')

map('n', ']d', diagnostic_goto(true), 'Next Diagnostic')
map('n', '[d', diagnostic_goto(false), 'Prev Diagnostic')
map('n', ']e', diagnostic_goto(true, 'ERROR'), 'Next Error')
map('n', '[e', diagnostic_goto(false, 'ERROR'), 'Prev Error')
map('n', ']w', diagnostic_goto(true, 'WARN'), 'Next Warning')
map('n', '[w', diagnostic_goto(false, 'WARN'), 'Prev Warning')

map('n', ']t', function() require('todo-comments').jump_next() end, 'Next TODO / Bug')
map('n', '[t', function() require('todo-comments').jump_prev() end, 'Previous TODO / Bug')

map({ 'n', 'x', 'o' }, ']m', function() require('nvim-treesitter-textobjects.move').goto_next_start '@function.outer' end, 'Next Method / Function Start')
map({ 'n', 'x', 'o' }, '[m', function() require('nvim-treesitter-textobjects.move').goto_previous_start '@function.outer' end, 'Prev Method / Function Start')
map({ 'n', 'x', 'o' }, ']M', function() require('nvim-treesitter-textobjects.move').goto_next_end '@function.outer' end, 'Next Method / Function End')
map({ 'n', 'x', 'o' }, '[M', function() require('nvim-treesitter-textobjects.move').goto_previous_end '@function.outer' end, 'Prev Method / Function End')
map({ 'n', 'x', 'o' }, ']]', function() require('nvim-treesitter-textobjects.move').goto_next_start '@class.outer' end, 'Next Class Start')
map({ 'n', 'x', 'o' }, '[[', function() require('nvim-treesitter-textobjects.move').goto_previous_start '@class.outer' end, 'Prev Class Start')
map({ 'n', 'x', 'o' }, '][', function() require('nvim-treesitter-textobjects.move').goto_next_end '@class.outer' end, 'Next Class End')
map({ 'n', 'x', 'o' }, '[]', function() require('nvim-treesitter-textobjects.move').goto_previous_end '@class.outer' end, 'Prev Class End')

local function select_ts(query)
  return function() require('nvim-treesitter-textobjects.select').select_textobject(query, 'textobjects') end
end

map({ 'x', 'o' }, 'am', select_ts '@function.outer', 'Around Function / Method')
map({ 'x', 'o' }, 'im', select_ts '@function.inner', 'Inner Function / Method')
map({ 'x', 'o' }, 'ac', select_ts '@class.outer', 'Around Class / Struct')
map({ 'x', 'o' }, 'ic', select_ts '@class.inner', 'Inner Class / Struct')
map({ 'x', 'o' }, 'ak', select_ts '@block.outer', 'Around Block')
map({ 'x', 'o' }, 'ik', select_ts '@block.inner', 'Inner Block')

map('n', '<leader>xl', function()
  local is_open = vim.fn.getloclist(0, { winid = 0 }).winid ~= 0
  local ok, err = pcall(is_open and vim.cmd.lclose or vim.cmd.lopen)
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end, 'Toggle Location List')

map('n', '<leader>xq', function()
  local is_open = vim.fn.getqflist({ winid = 0 }).winid ~= 0
  local ok, err = pcall(is_open and vim.cmd.cclose or vim.cmd.copen)
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end, 'Toggle Quickfix List')

map('n', '[q', vim.cmd.cprev, 'Prev Quickfix Item')
map('n', ']q', vim.cmd.cnext, 'Next Quickfix Item')
map('n', '[l', vim.cmd.lprev, 'Prev Location Item')
map('n', ']l', vim.cmd.lnext, 'Next Location Item')

map('n', '<leader>xx', extra('diagnostic', { scope = 'all' }), 'Workspace Diagnostics')
map('n', '<leader>xX', extra('diagnostic', { scope = 'current' }), 'Buffer Diagnostics')
map('n', '<leader>xt', function() require('mini.pick').registry.todo() end, 'Search TODOs / Fixes')
map('n', '<leader>xT', function() require('mini.pick').registry.todo { current_buffer = true } end, 'Search Buffer TODOs')
map('n', '<leader>xL', extra('list', { scope = 'location' }), 'Location List Picker')
map('n', '<leader>xQ', extra('list', { scope = 'quickfix' }), 'Quickfix List Picker')

map('n', '<leader>.', function() Snacks.scratch() end, 'Toggle Project Scratchpad')
map('n', '<leader>S', function() Snacks.scratch.select() end, 'Select Scratchpad')

-- ============================================================================
-- 8. DEBUGGING (DAP) & RUNNER (OVERSEER)
-- ============================================================================

local function dap() return require('plugins.code').load_dap() end

map('n', '<leader>dc', function() dap().continue() end, 'Start / Continue')
map('n', '<leader>di', function() dap().step_into() end, 'Step Into')
map('n', '<leader>do', function() dap().step_over() end, 'Step Over')
map('n', '<leader>dO', function() dap().step_out() end, 'Step Out')
map('n', '<leader>db', function() dap().toggle_breakpoint() end, 'Toggle Breakpoint')
map('n', '<leader>dB', function() dap().set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, 'Conditional Breakpoint')
map('n', '<leader>du', function()
  dap()
  require('dap-view').toggle()
end, 'Toggle Debug UI (dap-view)')

map('n', '<F5>', function() dap().continue() end, 'Debug: Continue')
map('n', '<F1>', function() dap().step_into() end, 'Debug: Step Into')
map('n', '<F2>', function() dap().step_over() end, 'Debug: Step Over')
map('n', '<F3>', function() dap().step_out() end, 'Debug: Step Out')
map('n', '<F7>', function()
  dap()
  require('dap-view').toggle()
end, 'Debug: Toggle UI (dap-view)')

map('n', '<leader>rr', '<cmd>OverseerRun<cr>', 'Run Task')
map('n', '<leader>rt', '<cmd>OverseerToggle<cr>', 'Toggle Task Runner')
map('n', '<leader>ra', '<cmd>OverseerTaskAction<cr>', 'Task Action')
map('n', '<leader>rR', function()
  local overseer = require 'overseer'
  local tasks = overseer.list_tasks {
    status = overseer.STATUS.SUCCESS,
    sort = function(a, b) return a.id > b.id end,
  }
  if #tasks > 0 then
    tasks[1]:restart()
  else
    vim.notify('No previously successful task found', vim.log.levels.WARN)
  end
end, 'Overseer: Rerun last successful task')

-- ============================================================================
-- 9. GIT INTEGRATION
-- ============================================================================

map('n', '<leader>gg', '<cmd>LazyGit<cr>', 'Open LazyGit')
map('n', '<leader>gl', extra 'git_commits', 'Git Commits (Log)')
map('n', '<leader>gL', function() require('mini.extra').pickers.git_commits { path = vim.api.nvim_buf_get_name(0) } end, 'Git Buffer Commits')
map('n', '<leader>gs', extra('git_files', { scope = 'modified' }), 'Git Status')
map('n', '<leader>gb', extra 'git_branches', 'Git Branches')
map('n', '<leader>gd', ':Diffmantic ', 'Diffmantic: Compare Buffer')
map('n', '<leader>gD', '<cmd>DiffmanticClear<cr>', 'Diffmantic: Clear Highlights')

map('n', '<leader>gi', function() require('mini.pick').registry.gh_issues() end, 'GitHub Issues (Open)')
map('n', '<leader>gI', function() require('mini.pick').registry.gh_issues { state = 'all' } end, 'GitHub Issues (All)')
map('n', '<leader>gp', function() require('mini.pick').registry.gh_prs() end, 'GitHub Pull Requests (Open)')
map('n', '<leader>gP', function() require('mini.pick').registry.gh_prs { state = 'all' } end, 'GitHub Pull Requests (All)')

-- ============================================================================
-- 10. UI & EDITOR TOGGLES (<leader>u)
-- ============================================================================

map('n', '<leader>ur', function()
  vim.cmd.nohlsearch()
  local mc_ns = vim.api.nvim_create_namespace 'nvim.multicursor'
  vim.api.nvim_buf_clear_namespace(0, mc_ns, 0, -1)
  vim.cmd 'diffupdate'
  vim.cmd.redraw { bang = true }
end, 'Redraw / Clear Highlights & Multicursors')
map('n', '<leader>ui', vim.show_pos, 'Inspect Position')
map('n', '<leader>uI', function()
  vim.treesitter.inspect_tree()
  vim.api.nvim_input 'I'
end, 'Inspect Treesitter Tree')
map('n', '<leader>uP', '<cmd>Pack<cr>', 'Plugin / Pack UI')
map('n', '<leader>uz', function() Snacks.zen() end, 'Toggle Zen Mode')
map('n', '<leader>up', function() require('core.noctalia').toggle_profile() end, 'Toggle Theme Profile (Noctalia/Standard)')

map('n', '<leader>uw', function()
  vim.wo.wrap = not vim.wo.wrap
  vim.notify('Wrap: ' .. (vim.wo.wrap and 'ON' or 'OFF'), vim.log.levels.INFO)
end, 'Toggle Line Wrap')

map('n', '<leader>us', function()
  vim.wo.spell = not vim.wo.spell
  vim.notify('Spell: ' .. (vim.wo.spell and 'ON' or 'OFF'), vim.log.levels.INFO)
end, 'Toggle Spell Check')

map('n', '<leader>ul', function()
  vim.wo.relativenumber = not vim.wo.relativenumber
  vim.notify('Relative Number: ' .. (vim.wo.relativenumber and 'ON' or 'OFF'), vim.log.levels.INFO)
end, 'Toggle Relative Numbers')

map('n', '<leader>uF', function()
  if vim.wo.foldmethod == 'manual' then
    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.cmd 'normal! zx'
    vim.notify('Folding: Treesitter (expr)', vim.log.levels.INFO)
  else
    vim.wo.foldmethod = 'manual'
    vim.notify('Folding: Manual (existing folds preserved)', vim.log.levels.INFO)
  end
end, 'Toggle Fold Method (Treesitter / Manual)')

map('n', '<leader>ud', function()
  local enabled = not vim.diagnostic.is_enabled()
  vim.diagnostic.enable(enabled)
  vim.notify('Diagnostics: ' .. (enabled and 'ON' or 'OFF'), vim.log.levels.INFO)
end, 'Toggle Diagnostics')

map('n', '<leader>uc', function()
  local next_val = vim.wo.conceallevel > 0 and 0 or 2
  vim.wo.conceallevel = next_val
  vim.notify('Conceallevel: ' .. next_val, vim.log.levels.INFO)
end, 'Toggle Conceal Level')

-- ============================================================================
-- 11. SESSIONS & QUITTING
-- ============================================================================

map('n', '<leader>qs', function() pcall(function() require('mini.sessions').read() end) end, 'Restore Session (CWD)')
map('n', '<leader>qS', function() pcall(function() require('mini.sessions').select() end) end, 'Select Session')
map('n', '<leader>ql', function() pcall(function() require('mini.sessions').read 'latest' end) end, 'Restore Last Session')
map('n', '<leader>qw', function() pcall(function() require('mini.sessions').write() end) end, 'Save Session')
map('n', '<leader>qq', '<cmd>qa<cr>', 'Quit All')

-- ============================================================================
-- 12. TASKS, BUGS & TIME FOOTPRINTS (<leader>t)
-- ============================================================================

map('n', '<leader>tb', function() require('tasks.board').open() end, 'Tasks: Open Project Board')
map({ 'n', 'v' }, '<leader>tB', function() require('tasks.capture').capture_bug_at_cursor() end, 'Tasks: Capture Bug at Cursor')
map('n', '<leader>tc', function() require('tasks.capture').quick_add() end, 'Tasks: Quick Capture')
map('n', '<leader>tl', function() require('tasks.pickers').pick_issues() end, 'Tasks: Search Project Tasks & Bugs')
map('n', '<leader>tL', function() require('tasks.pickers').pick_issues { all = true } end, 'Tasks: Search All Projects')
map('n', '<leader>tt', function() require('tasks.pickers').pick_timer() end, 'Tasks: Switch / Toggle Timer')
map('n', '<leader>tp', function() require('tasks.tracker').toggle_pause() end, 'Tasks: Pause / Resume Timer')
map('n', '<leader>to', function() require('tasks').open_active_detail() end, 'Tasks: Open Active Ticket Detail')
map('n', '<leader>tg', function() require('tasks').git_menu() end, 'Tasks: Git Actions & Branch/Hooks')
map('n', '<leader>tr', function() require('tasks.report').open() end, 'Tasks: Time & Git Footprint Report')
map('n', '<leader>tu', function() require('tasks.report').open_tui() end, 'Tasks: Visual Kitty TUI (tsk ui)')
map('n', '<leader>ts', function() require('tasks.pickers').pick_gh_sync() end, 'Tasks: Sync GitHub Issues')
map('n', '<leader>tx', function() require('tasks.capture').promote_comment_to_ticket() end, 'Tasks: Promote TODO/FIXME to Ticket')
