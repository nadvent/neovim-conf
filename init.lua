---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

vim.o.autoread = true

-- Trigger autoread when the file changes outside or when switching buffers
vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
  callback = function()
    if vim.fn.mode() ~= 'c' then
      vim.cmd('checktime')
    end
  end,
})
require('core.options')
require('core.themes')
require('core.autocmd')
require('plugins.code')
require('plugins.telescope')
require('core.keymaps')
require('plugins.init')
require('plugins.ux')
require('plugins.statusline')


require('snacks').setup {
    bigfile = { enabled = true },
    dashboard = {
        enabled = true,
          sections = {
            { section = "keys", gap = 1, padding = 1 },
            { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
            { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
            {
              pane = 2,
              icon = " ",
              title = "Git Status",
              section = "terminal",
              enabled = function()
                return Snacks.git.get_root() ~= nil
              end,
              cmd = "git status --short --branch --renames",
              height = 5,
              padding = 1,
              ttl = 5 * 60,
              indent = 3,
            },
          },
    },
    explorer = { enabled = false },
    indent = { enabled = false },
    input = { enabled = true },
    picker = { enabled = false },
    notifier = { enabled = true },
    quickfile = { enabled = true },
    scope = { enabled = true },
    scroll = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
}
