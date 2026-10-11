-- Icons
local icons = require("icons")

-- Mode labels
local modes = {
  ["n"] = "NORMAL",
  ["no"] = "NORMAL",
  ["v"] = "VISUAL",
  ["V"] = "VISUAL LINE",
  ["\22"] = "VISUAL BLOCK",
  ["s"] = "SELECT",
  ["S"] = "SELECT LINE",
  ["\19"] = "SELECT BLOCK",
  ["i"] = "INSERT",
  ["ic"] = "INSERT",
  ["R"] = "REPLACE",
  ["Rv"] = "VISUAL REPLACE",
  ["c"] = "COMMAND",
  ["cv"] = "VIM EX",
  ["ce"] = "EX",
  ["r"] = "PROMPT",
  ["rm"] = "MOAR",
  ["r?"] = "CONFIRM",
  ["!"] = "SHELL",
  ["t"] = "TERMINAL",
}

-- Mode highlighting
-- These highlight groups affect only the mode indicator.
-- Customize the foreground (fg) and background (bg) as desired.
local mode_highlights = {
  StatuslineModeNormal = { fg = "#fff9e8", bg = "#1d1c11", bold = true },
  StatuslineModeInsert = { fg = "#1d1c11", bg = "#9bd85c", bold = true },
  StatuslineModeVisual = { fg = "#fff9e8", bg = "#4A1985", bold = true },
  StatuslineModeReplace = { fg = "#fff9e8", bg = "#ba1a1a", bold = true },
  StatuslineModeCommand = { fg = "#1d1c11", bg = "#00B4D8", bold = true },
  StatuslineModeTerminal = { fg = "#fff9e8", bg = "#675f22", bold = true },
  StatuslineModeOther = { fg = "#fff9e8", bg = "#4a4733", bold = true },
}

local function setup_mode_highlights()
  for group, colors in pairs(mode_highlights) do
    vim.api.nvim_set_hl(0, group, colors)
  end
end

-- Returns the current mode's display name.
local function mode()
  local current_mode = vim.api.nvim_get_mode().mode
  return string.format(" %s ", modes[current_mode] or current_mode):upper()
end

-- Selects the highlight group for the current mode.
local function update_mode_colors()
  local current_mode = vim.api.nvim_get_mode().mode

  if current_mode == "n" or current_mode == "no" then
    return "%#StatuslineModeNormal#"
  elseif current_mode == "i" or current_mode == "ic" then
    return "%#StatuslineModeInsert#"
  elseif current_mode == "v"
    or current_mode == "V"
    or current_mode == "\22"
    or current_mode == "s"
    or current_mode == "S"
    or current_mode == "\19"
  then
    return "%#StatuslineModeVisual#"
  elseif current_mode == "R" or current_mode == "Rv" then
    return "%#StatuslineModeReplace#"
  elseif current_mode == "c" or current_mode == "cv" or current_mode == "ce" then
    return "%#StatuslineModeCommand#"
  elseif current_mode == "t" then
    return "%#StatuslineModeTerminal#"
  end

  return "%#StatuslineModeOther#"
end

-- File path and name
-- Displays the directory relative to the current working directory.
local function filepath()
  local fpath = vim.fn.fnamemodify(vim.fn.expand("%"), ":.:h")

  if fpath == "" or fpath == "." then
    return " "
  end

  return string.format(" %%<%s/", fpath)
end

local function filename()
  local fname = vim.fn.expand("%:t")

  if fname == "" then
    return "[No Name] "
  end

  return fname .. " "
end

-- Filetype icon
-- Uses nvim-web-devicons, falling back to your shared file icon.
local function filetype_icon()
  local fname = vim.fn.expand("%:t")

  if fname == "" then
    return icons.symbol_kinds.File .. " "
  end

  local ok, devicons = pcall(require, "nvim-web-devicons")

  if ok then
    local icon = devicons.get_icon(fname, nil, { default = true })

    if icon then
      return icon .. " "
    end
  end

  return icons.symbol_kinds.File .. " "
end

-- Line information
-- Displays current line : total lines, e.g. 25:180.
local function lineinfo()
  if vim.bo.filetype == "alpha" then
    return ""
  end

  local current_line = vim.fn.line(".")
  local total_lines = vim.api.nvim_buf_line_count(0)

  return string.format(" %d:%d ", current_line, total_lines)
end

-- LSP diagnostics
-- Displays the count of each diagnostic severity.
local function lsp()
  local count = {}

  local levels = {
    errors = "Error",
    warnings = "Warn",
    info = "Info",
    hints = "Hint",
  }

  for name, level in pairs(levels) do
    count[name] = vim.tbl_count(
      vim.diagnostic.get(0, {
        severity = vim.diagnostic.severity[level],
      })
    )
  end

  local errors = ""
  local warnings = ""
  local hints = ""
  local info = ""

  if count.errors ~= 0 then
    errors = " %#LspDiagnosticsSignError#"
      .. icons.diagnostics.ERROR .. " " .. count.errors
  end

  if count.warnings ~= 0 then
    warnings = " %#LspDiagnosticsSignWarning#"
      .. icons.diagnostics.WARN .. " " .. count.warnings
  end

  if count.hints ~= 0 then
    hints = " %#LspDiagnosticsSignHint#"
      .. icons.diagnostics.HINT .. " " .. count.hints
  end

  if count.info ~= 0 then
    info = " %#LspDiagnosticsSignInformation#"
      .. icons.diagnostics.INFO .. " " .. count.info
  end

  return errors .. warnings .. hints .. info .. "%#Normal#"
end

-- Git information
-- Displays added, changed, and removed lines, plus the branch.
local function vcs()
  local git_info = vim.b.gitsigns_status_dict

  if not git_info or not git_info.head or git_info.head == "" then
    return ""
  end

  local added = ""
  local changed = ""
  local removed = ""

  if (git_info.added or 0) > 0 then
    added = "%#GitSignsAdd#+"
      .. git_info.added .. " "
  end

  if (git_info.changed or 0) > 0 then
    changed = "%#GitSignsChange#~"
      .. git_info.changed .. " "
  end

  if (git_info.removed or 0) > 0 then
    removed = "%#GitSignsDelete#-"
      .. git_info.removed .. " "
  end

  return table.concat({
    " ",
    added,
    changed,
    removed,
    " ",
    "%#GitSignsAdd#",
    icons.misc.git,
    " ",
    git_info.head,
    " %#Normal#",
  })
end

-- Statusline layouts
Statusline = {}

-- Active window: mode, file path, filename, diagnostics,
-- Git information, filetype icon, and line position.
Statusline.active = function()
  return table.concat({
    update_mode_colors(),
    mode(),
    "%#StatusLine# ",
    filepath(),
    filename(),
    "%#StatusLine#",
    lsp(),
    "%=%#StatusLineExtra#",
    vcs(),
    filetype_icon(),
    lineinfo(),
  })
end

-- Inactive window: display the full file path.
function Statusline.inactive()
  return " %F"
end

-- NvimTree window: compact statusline.
function Statusline.short()
  return "%#StatusLineNC# " .. icons.symbol_kinds.Folder .. " NvimTree"
end

-- Autocmds
-- Select the appropriate statusline for active, inactive, and NvimTree windows.
local id = vim.api.nvim_create_augroup("Statusline", { clear = true })

vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
  group = id,
  pattern = "*",
  callback = function()
    vim.opt_local.statusline = "%!v:lua.Statusline.active()"
  end,
})

vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
  group = id,
  pattern = "*",
  callback = function()
    vim.opt_local.statusline = "%!v:lua.Statusline.inactive()"
  end,
})

vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "FileType" }, {
  group = id,
  pattern = "NvimTree",
  callback = function()
    vim.opt_local.statusline = "%!v:lua.Statusline.short()"
  end,
})

-- Initialize the custom mode colors.
setup_mode_highlights()

-- Reapply custom mode colors after a colorscheme change.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = id,
  callback = setup_mode_highlights,
})

