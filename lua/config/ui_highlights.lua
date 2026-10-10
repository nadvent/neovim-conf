local M = {}

function M.setup()
  -- Read the palette currently loaded by base16-colorscheme.
  local colors = require("base16-colorscheme").colors

  -- Built-in Neovim statusline
  vim.api.nvim_set_hl(0, "StatusLine", {
    fg = colors.base00,
    bg = colors.base04,
    bold = true,
  })

  vim.api.nvim_set_hl(0, "StatusLineNC", {
    fg = colors.base03,
    bg = colors.base01,
  })

  -- which-key popup
  vim.api.nvim_set_hl(0, "WhichKeyNormal", {
    fg = colors.base05,
    bg = colors.base00,
  })

  vim.api.nvim_set_hl(0, "WhichKeyBorder", {
    fg = colors.base0D,
    bg = colors.base00,
  })

  vim.api.nvim_set_hl(0, "WhichKeyTitle", {
    fg = colors.base0D,
    bg = colors.base00,
    bold = true,
  })

  vim.api.nvim_set_hl(0, "WhichKey", {
    fg = colors.base0D,
    bold = true,
  })

  vim.api.nvim_set_hl(0, "WhichKeyDesc", {
    fg = colors.base05,
  })

  vim.api.nvim_set_hl(0, "WhichKeyGroup", {
    fg = colors.base0E,
  })

  vim.api.nvim_set_hl(0, "WhichKeySeparator", {
    fg = colors.base03,
  })
end

return M
