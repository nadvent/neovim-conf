local M = {}

--- Diagnostic severities.
M.diagnostics = {
  ERROR = '',
  WARN = '',
  HINT = '',
  INFO = '',
}

--- Git icons.
M.git = {
  branch = '',
  added = ' ',
  changed = ' ',
  removed = ' ',
}

--- UI & statusline glyphs.
M.ui = {
  search = '',
  caret = '▏',
  bar = '▊',
  pos = '',
  folder = '󰉋',
  file = '󰈔',
}

local real_icons_cat = {
  file = 'file',
  directory = 'folder',
  filetype = 'filetype',
}

--- Resolve a file, directory, or filetype icon and highlight group.
--- Uses real-icons.nvim first (unless `opts.glyph_only` is set), falling back to mini.icons.
---@param category 'file'|'directory'|'filetype'|'extension'
---@param name string
---@param opts? { glyph_only?: boolean }
---@return string icon, string|nil hl
function M.file_icon(category, name, opts)
  opts = opts or {}

  if name and name ~= '' then
    if not opts.glyph_only and real_icons_cat[category] then
      local ok_ri, real_icons = pcall(require, 'real-icons')
      if ok_ri and type(real_icons.get) == 'function' then
        local lookup = (category == 'file' or category == 'directory') and vim.fs.basename(name) or name
        local ok_get, icon, hl = pcall(real_icons.get, real_icons_cat[category], lookup)
        if ok_get and icon and icon ~= '' then return icon, hl end
      end
    end

    local ok_mi, mini_icons = pcall(require, 'mini.icons')
    if ok_mi and type(mini_icons.get) == 'function' then
      local ok_get, icon, hl = pcall(mini_icons.get, category, name)
      if ok_get and icon and icon ~= '' then return icon, hl end
    end
  end

  if category == 'directory' then return M.ui.folder, 'Directory' end
  return M.ui.file, nil
end

return M
