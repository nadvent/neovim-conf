local util = require 'core.util'

local M = {}

local state = {
  plugin_keys = '⌨S',
  selected_key = nil,
  expand_hints = {},
}

local builtin_hints = {
  [')'] = 'Balanced ()',
  ['('] = 'Balanced () [with space]',
  [']'] = 'Balanced []',
  ['['] = 'Balanced [] [with space]',
  ['}'] = 'Balanced {}',
  ['{'] = 'Balanced {} [with space]',
  ['>'] = 'Balanced <>',
  ['<'] = 'Balanced <> [with space]',
  ['b'] = 'Alias: ), ], or }',
  ['q'] = 'Alias: ", \', or `',
  ['"'] = 'Double quotes ""',
  ["'"] = "Single quotes ''",
  ['`'] = 'Backticks ``',
  ['t'] = 'HTML/XML Tag',
  ['f'] = 'Function call',
  ['?'] = 'Interactive prompt',
  ['$'] = 'Math ($...$)',
  ['*'] = 'Asterisks (*...*)',
  ['_'] = 'Underscores (_..._)',
  ['~'] = 'Tildes (~...~)',
  ['='] = 'Equals (=...=)',
}

local wk_plugin = {
  name = 'mini-surround',
  expand = function()
    local items = {}
    for key, label in pairs(state.expand_hints) do
      table.insert(items, {
        key = key,
        desc = label,
        value = '',
        action = function() state.selected_key = key end,
      })
    end
    table.sort(items, function(a, b) return a.key < b.key end)
    return items
  end,
  setup = function() end,
}

local function merge_custom_surroundings(hints, custom)
  if not custom then return end
  for k, v in pairs(custom) do
    if type(k) == 'string' and #k == 1 then
      local label = v.desc or v.label
      if not label and v.output and v.output.left and v.output.right then label = v.output.left .. '…' .. v.output.right end
      hints[k] = label or ('Custom: ' .. k)
    end
  end
end

local function get_hints()
  local hints = vim.deepcopy(builtin_hints)
  local ms = _G.MiniSurround
  merge_custom_surroundings(hints, ms and ms.config and ms.config.custom_surroundings)
  local b_config = vim.b.minisurround_config
  merge_custom_surroundings(hints, b_config and b_config.custom_surroundings)
  return hints
end

function M.setup()
  local ok_ms, ms = pcall(require, 'mini.surround')
  if not ok_ms then return end

  local ok_wk, wk = pcall(require, 'which-key')
  if not ok_wk then return end

  local H = util.get_upvalue(ms.add, 'H')

  if not H or not H.user_surround_id then return end

  wk.add {
    {
      [1] = state.plugin_keys,
      plugin = wk_plugin.name,
      icon = { icon = '󰗅', color = 'blue' },
      desc = 'Surround Characters',
      mode = { 'n', 'x', 'o' },
    },
  }

  local wk_plugins = require 'which-key.plugins'
  wk_plugins.plugins[wk_plugin.name] = wk_plugin
  wk_plugins._setup(wk_plugin, {})

  local orig_user_surround_id = H.user_surround_id

  H.user_surround_id = function(surr_type)
    local cur_mode = vim.api.nvim_get_mode().mode:sub(1, 1)
    if cur_mode == 'i' then return orig_user_surround_id(surr_type) end

    state.selected_key = nil
    state.expand_hints = get_hints()

    pcall(function()
      wk.show {
        keys = state.plugin_keys,
        mode = cur_mode == 'x' and 'x' or 'n',
      }
    end)

    if state.selected_key then return state.selected_key end
    return orig_user_surround_id(surr_type)
  end
end

return M
