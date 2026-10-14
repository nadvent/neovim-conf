-- keymap.lua
-- Global keymaps, which-key groups, and diagnostic display settings.
--
-- Plugin-specific buffer-local mappings (for example, Gitsigns on_attach
-- mappings and the additional LSP mappings) should stay beside the plugin
-- configuration that owns them.

-- ============================================================
-- Which-key
-- ============================================================

vim.pack.add({ "https://github.com/folke/which-key.nvim" })

local wk = require("which-key")

wk.setup({
  -- Delay between pressing a key and opening which-key (milliseconds).
  delay = 0,
  icons = { mappings = vim.g.have_nerd_font },
})

-- Only declare groups that currently have mappings in this file or in the
-- separate Gitsigns/LSP configuration. Add Project, Run, Notes, Marks, and
-- Windows leader groups when those namespaces gain their first mappings.
wk.add({
  { "<leader>b", group = "Buffers" },
  { "<leader>c", group = "Code / LSP" },
  { "<leader>d", group = "Debug" },
  { "<leader>f", group = "Files" },
  { "<leader>h", group = "Git Hunks", mode = { "n", "v" } },
  { "<leader>q", group = "Session / Quit" },
  { "<leader>s", group = "Search" },
  { "<leader>t", group = "Toggles" },
  { "<leader>u", group = "UI / Editor" },
  { "<leader>x", group = "Diagnostics / Lists" },
  { "<leader><Tab>", group = "Tabs" },
  { "gr", group = "LSP", mode = "n" },
})

local map = vim.keymap.set

-- ============================================================
-- Core editing behavior
-- ============================================================

-- Clear search highlighting.
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear Search Highlight" })

-- Move by screen line when no count is supplied; preserve normal counted moves.
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", {
  desc = "Down",
  expr = true,
  silent = true,
})
map({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", {
  desc = "Down",
  expr = true,
  silent = true,
})
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", {
  desc = "Up",
  expr = true,
  silent = true,
})
map({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", {
  desc = "Up",
  expr = true,
  silent = true,
})

-- Make n/N follow the direction of the last search and reveal folded matches.
map("n", "n", "'Nn'[v:searchforward].'zv'", {
  expr = true,
  desc = "Next Search Result",
})
map({ "x", "o" }, "n", "'Nn'[v:searchforward]", {
  expr = true,
  desc = "Next Search Result",
})
map("n", "N", "'nN'[v:searchforward].'zv'", {
  expr = true,
  desc = "Previous Search Result",
})
map({ "x", "o" }, "N", "'nN'[v:searchforward]", {
  expr = true,
  desc = "Previous Search Result",
})

-- Create undo breakpoints after punctuation in insert mode.
map("i", ",", ",<c-g>u", { desc = "Comma (undo breakpoint)" })
map("i", ".", ".<c-g>u", { desc = "Period (undo breakpoint)" })
map("i", ";", ";<c-g>u", { desc = "Semicolon (undo breakpoint)" })

-- Save from common editing modes.
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

-- Use the configured keyword program.
map("n", "<leader>K", "<cmd>norm! K<cr>", { desc = "Keyword Program" })

-- Keep the selection after indenting in visual mode.
map("x", "<", "<gv", { desc = "Indent Left and Reselect" })
map("x", ">", ">gv", { desc = "Indent Right and Reselect" })

-- Add a comment on the line below/above the cursor.
map("n", "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", {
  desc = "Add Comment Below",
})
map("n", "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", {
  desc = "Add Comment Above",
})

-- Move Lines
map("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
map("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
map("v", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })

-- ============================================================
-- Files, buffers, and explorer
-- ============================================================

map("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New File" })

map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>bd", function()
  Snacks.bufdelete()
end, { desc = "Delete Buffer" })
map("n", "<leader>bo", function()
  Snacks.bufdelete.other()
end, { desc = "Delete Other Buffers" })
map("n", "<leader>bi", function()
  Snacks.bufdelete.invisible()
end, { desc = "Delete Invisible Buffers" })
map("n", "<leader>bD", "<cmd>:bd<cr>", { desc = "Delete Buffer and Window" })
-- Keep both the grouped mapping and Kickstart's familiar buffer-picker chord.
local builtin = require("telescope.builtin")
map("n", "<leader>bb", builtin.buffers, { desc = "List Buffers" })

-- Yazi: open at the current file/directory.
map({ "n", "v" }, "<leader>ff", "<cmd>Yazi<cr>", {
  desc = "Open Yazi at Current File",
  remap = false,
})

map({ "n", "v" }, "<leader>fF", "<cmd>Yazi cwd<cr>", {
  desc = "Open Yazi at Current Working Directory",
  remap = false,
})
-- ============================================================
-- Search (Telescope)
-- ============================================================

map("n", "<leader>sh", builtin.help_tags, { desc = "Search Help" })
map("n", "<leader>sk", builtin.keymaps, { desc = "Search Keymaps" })
map("n", "<leader>sf", builtin.find_files, { desc = "Search Files" })
map("n", "<leader>ss", builtin.builtin, { desc = "Search Telescope Pickers" })
map({ "n", "v" }, "<leader>sw", builtin.grep_string, { desc = "Search Current Word" })
map("n", "<leader>sg", builtin.live_grep, { desc = "Search by Grep" })
map("n", "<leader>sd", builtin.diagnostics, { desc = "Search Diagnostics" })
map("n", "<leader>sr", builtin.resume, { desc = "Resume Search" })
map("n", "<leader>s.", builtin.oldfiles, { desc = "Search Recent Files" })
map("n", "<leader>sc", builtin.commands, { desc = "Search Commands" })

-- Fuzzy-search the current buffer.
map("n", "<leader>/", function()
  builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
    winblend = 10,
    previewer = false,
  }))
end, { desc = "Search Current Buffer" })

-- Search only currently open files.
map("n", "<leader>s/", function()
  builtin.live_grep({
    grep_open_files = true,
    prompt_title = "Live Grep in Open Files",
  })
end, { desc = "Search Open Files" })

-- Search this Neovim configuration.
map("n", "<leader>sn", function()
  builtin.find_files({ cwd = vim.fn.stdpath("config"), follow = true })
end, { desc = "Search Neovim Config" })

-- ============================================================
-- Code / LSP navigation
-- ============================================================

-- Telescope-based LSP pickers are installed buffer-locally when an LSP attaches. (see plugins.code)

map("n", "grr", builtin.lsp_references, {
    buffer = buf,
    desc = "Goto References",
})
map("n", "gri", builtin.lsp_implementations, {
    buffer = buf,
    desc = "Goto Implementations",
})
map("n", "grd", builtin.lsp_definitions, {
    buffer = buf,
    desc = "Goto Definitions",
})
map("n", "gO", builtin.lsp_document_symbols, {
    buffer = buf,
    desc = "Document Symbols",
})
map("n", "gW", builtin.lsp_dynamic_workspace_symbols, {
    buffer = buf,
    desc = "Workspace Symbols",
})
map("n", "grt", builtin.lsp_type_definitions, {
    buffer = buf,
    desc = "Goto Type Definition",
})
-- Trouble's code/LSP views belong in the Code group.
map("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", {
  desc = "Toggle Symbols",
})
map("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", {
  desc = "Toggle LSP References / Definitions",
})

map({ 'n', 'v' }, '<leader>cf', function() require('conform').format { async = true } end, { desc = '[F]ormat buffer' })
-- ============================================================
-- Diagnostics, quickfix, and location lists
-- ============================================================

vim.diagnostic.config({
  update_in_insert = false,
  severity_sort = true,
  float = { border = "rounded", source = "if_many" },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },

  -- Toggle virtual_text / virtual_lines here to match your preference.
  virtual_text = true,
  virtual_lines = false,

  -- Show the diagnostic under the cursor when jumping between diagnostics.
  jump = {
    on_jump = function(_, bufnr)
      vim.diagnostic.open_float({
        bufnr = bufnr,
        scope = "cursor",
        focus = false,
      })
    end,
  },
})

local diagnostic_goto = function(next, severity)
  return function()
    vim.diagnostic.jump({
      count = (next and 1 or -1) * vim.v.count1,
      severity = severity and vim.diagnostic.severity[severity] or nil,
      float = true,
    })
  end
end

map("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
map("n", "<leader>xD", vim.diagnostic.setloclist, { desc = "Send Diagnostics to Location List" })
map("n", "]d", diagnostic_goto(true), { desc = "Next Diagnostic" })
map("n", "[d", diagnostic_goto(false), { desc = "Previous Diagnostic" })
map("n", "]e", diagnostic_goto(true, "ERROR"), { desc = "Next Error" })
map("n", "[e", diagnostic_goto(false, "ERROR"), { desc = "Previous Error" })
map("n", "]w", diagnostic_goto(true, "WARN"), { desc = "Next Warning" })
map("n", "[w", diagnostic_goto(false, "WARN"), { desc = "Previous Warning" })

-- Toggle the location list for the current window.
map("n", "<leader>xl", function()
  local is_open = vim.fn.getloclist(0, { winid = 0 }).winid ~= 0
  local ok, err = pcall(is_open and vim.cmd.lclose or vim.cmd.lopen)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
  end
end, { desc = "Toggle Location List" })

-- Toggle the quickfix list.
map("n", "<leader>xq", function()
  local is_open = vim.fn.getqflist({ winid = 0 }).winid ~= 0
  local ok, err = pcall(is_open and vim.cmd.cclose or vim.cmd.copen)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
  end
end, { desc = "Toggle Quickfix List" })

map("n", "[q", vim.cmd.cprev, { desc = "Previous Quickfix Item" })
map("n", "]q", vim.cmd.cnext, { desc = "Next Quickfix Item" })

-- Trouble diagnostic views.
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", {
  desc = "Toggle Diagnostics",
})
map("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", {
  desc = "Toggle Buffer Diagnostics",
})
map("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", {
  desc = "Toggle Location List (Trouble)",
})
map("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", {
  desc = "Toggle Quickfix List (Trouble)",
})

-- ============================================================
-- Debugging (nvim-dap) and Runner (overseer)
-- ============================================================

local dap = function()
  return require("dap")
end

-- Leader-based controls are the discoverable, grouped interface.
map("n", "<leader>dc", function() dap().continue() end, { desc = "Start / Continue" })
map("n", "<leader>di", function() dap().step_into() end, { desc = "Step Into" })
map("n", "<leader>do", function() dap().step_over() end, { desc = "Step Over" })
map("n", "<leader>dO", function() dap().step_out() end, { desc = "Step Out" })
map("n", "<leader>db", function() dap().toggle_breakpoint() end, { desc = "Toggle Breakpoint" })
map("n", "<leader>dB", function()
  dap().set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Set Conditional Breakpoint" })
map("n", "<leader>du", function() require("dapui").toggle() end, { desc = "Toggle Debug UI" })

-- Keep conventional function-key aliases as quick, non-leader alternatives.
map("n", "<F5>", function() dap().continue() end, { desc = "Debug: Start / Continue" })
map("n", "<F1>", function() dap().step_into() end, { desc = "Debug: Step Into" })
map("n", "<F2>", function() dap().step_over() end, { desc = "Debug: Step Over" })
map("n", "<F3>", function() dap().step_out() end, { desc = "Debug: Step Out" })
map("n", "<F7>", function() require("dapui").toggle() end, { desc = "Debug: Toggle UI" })

map("n", "<leader>rr", "<cmd>OverseerRun<CR>", { desc = "Run Overseer"})
map("n", "<leader>rt", "<cmd>OverseerToggle<CR>", { desc = "Toggle Overseer"})
-- ============================================================
-- UI / editor utilities
-- ============================================================

map("n", "<leader>ur", "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>", {
  desc = "Redraw / Clear Search / Update Diff",
})
map("n", "<leader>ui", vim.show_pos, { desc = "Inspect Position" })
map("n", "<leader>uI", function()
  vim.treesitter.inspect_tree()
  vim.api.nvim_input("I")
end, { desc = "Inspect Treesitter Tree" })
map("n", "<leader>uP", "<cmd>Pack<cr>", { desc = "Plugin / Pack UI" })

-- ============================================================
-- Windows, tabs, and terminal
-- ============================================================

map("n", "<C-h>", "<C-w><C-h>", { desc = "Focus Left Window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Focus Right Window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Focus Lower Window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Focus Upper Window" })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete Window", remap = true })
map("n", "<leader>-", "<C-W>s", { desc = "Split Window Below", remap = true })
map("n", "<leader>|", "<C-W>v", { desc = "Split Window Right", remap = true })

map("n", "<leader><Tab>l", "<cmd>tablast<cr>", { desc = "Last Tab" })
map("n", "<leader><Tab>o", "<cmd>tabonly<cr>", { desc = "Close Other Tabs" })
map("n", "<leader><Tab>f", "<cmd>tabfirst<cr>", { desc = "First Tab" })
map("n", "<leader><Tab><Tab>", "<cmd>tabnew<cr>", { desc = "New Tab" })
map("n", "<leader><Tab>]", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "<leader><Tab>d", "<cmd>tabclose<cr>", { desc = "Close Tab" })
map("n", "<leader><Tab>[", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })

map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit Terminal Mode" })

-- ============================================================
-- Sessions and quitting
-- ============================================================

map("n", "<leader>qs", function()
  require("persistence").load()
end, { desc = "Load Session for Current Directory" })

map("n", "<leader>qS", function()
  require("persistence").select()
end, { desc = "Select Session" })

map("n", "<leader>ql", function()
  require("persistence").load({ last = true })
end, { desc = "Load Last Session" })

map("n", "<leader>qd", function()
  require("persistence").stop()
end, { desc = "Stop Session Saving" })

map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })


-- ============================================================
-- Git
-- ============================================================
if vim.fn.executable("lazygit") == 1 then
  map("n", "<leader>gg", function() Snacks.lazygit( { cwd = LazyVim.root.git() }) end, { desc = "Lazygit (Root Dir)" })
  map("n", "<leader>gG", function() Snacks.lazygit() end, { desc = "Lazygit (cwd)" })
end

map("n", "<leader>gL", function() Snacks.picker.git_log() end, { desc = "Git Log (cwd)" })
map("n", "<leader>gb", function() Snacks.picker.git_log_line() end, { desc = "Git Blame Line" })
map("n", "<leader>gf", function() Snacks.picker.git_log_file() end, { desc = "Git Current File History" })
map("n", "<leader>gl", function() Snacks.picker.git_log({ cwd = LazyVim.root.git() }) end, { desc = "Git Log" })
map({ "n", "x" }, "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Git Browse (open)" })
map({"n", "x" }, "<leader>gY", function()
  Snacks.gitbrowse({ open = function(url) vim.fn.setreg("+", url) end, notify = false })
end, { desc = "Git Browse (copy)" })



-- ============================================================
-- Reserved namespaces for future workflows
-- ============================================================
-- Add these which-key groups when the corresponding mappings are implemented:
--   <leader>g  Git repository operations (status, log, branches, LazyGit)
--   <leader>m  Marks / code bookmarks
--   <leader>n  Notes and document tools (LaTeX / Typst)
--   <leader>p  Project / build (CMake, tests, task runner)
--   <leader>r  Run / REPL (uv, Python scripts, interactive shells)
--   <leader>w  Window layout / resize commands
--
-- Gitsigns on_attach mappings and the additional LSP mappings you showed are
-- intentionally left in their owning plugin configuration files.
