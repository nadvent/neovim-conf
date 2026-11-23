local M = {}

local function norm_expand(path) return vim.fs.normalize(vim.fn.expand(path)) end

M.PATHS = {
  projects = norm_expand '~/Projects',
  leetcode = norm_expand '~/Projects/leetCode',
  gspread = norm_expand '~/Projects/Google',
  snippets = norm_expand '~/Documents/Snippets',
}

--- Expand a GitHub `owner/repo` shorthand into a full HTTPS URL.
---@param repo string
---@return string
function M.gh(repo) return 'https://github.com/' .. repo end

--- Create or clear a namespaced augroup.
---@param name string
---@return integer
function M.augroup(name) return vim.api.nvim_create_augroup('nvim_' .. name, { clear = true }) end

--- Set a keymap accepting either a description string or an options table.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts? string|vim.keymap.set.Opts
function M.map(mode, lhs, rhs, opts)
  local resolved = type(opts) == 'string' and { desc = opts } or vim.deepcopy(opts or {})
  vim.keymap.set(mode, lhs, rhs, resolved)
end

--- Return true when `path` equals or resides inside `dir`.
---@param path? string
---@param dir? string
---@return boolean
function M.path_in_dir(path, dir)
  if not path or path == '' or not dir or dir == '' then return false end
  local norm_path = vim.fs.normalize(path)
  local norm_dir = vim.fs.normalize(dir)
  return norm_path == norm_dir or vim.startswith(norm_path, norm_dir .. '/')
end

--- Return true when either cwd or the target buffer resides inside `dir`.
---@param dir string
---@param buf? integer|false Pass false to check cwd only.
---@return boolean
function M.in_project(dir, buf)
  if M.path_in_dir(vim.fn.getcwd(), dir) then return true end
  if buf == false then return false end
  local target_buf = buf or 0
  if not vim.api.nvim_buf_is_valid(target_buf) then return false end
  return M.path_in_dir(vim.api.nvim_buf_get_name(target_buf), dir)
end

--- Return true when in the LeetCode workspace or buffer.
---@param buf? integer|false
---@return boolean
function M.in_leetcode(buf) return M.in_project(M.PATHS.leetcode, buf) end

--- Return true when in the Google Sheets project workspace or buffer.
---@param buf? integer|false
---@return boolean
function M.in_gspread(buf) return M.in_project(M.PATHS.gspread, buf) end

--- List normalized directory paths under `~/Projects`.
---@return string[]
function M.list_projects()
  local projects = {}
  for _, p in ipairs(vim.fn.glob(M.PATHS.projects .. '/*', false, true)) do
    p = vim.fs.normalize(p)
    if vim.fn.isdirectory(p) == 1 then table.insert(projects, p) end
  end
  return projects
end

local function clamp_byte(c) return math.min(math.max(0, math.floor(c)), 255) end

--- Format RGB components (0..255) as a `#rrggbb` hex string.
---@param r number
---@param g number
---@param b number
---@return string
function M.rgb_to_hex(r, g, b) return string.format('#%02x%02x%02x', clamp_byte(r), clamp_byte(g), clamp_byte(b)) end

--- Parse an integer highlight color or `#rrggbb` hex string into RGB bytes.
---@param color number|string|nil
---@return { r: integer, g: integer, b: integer }
function M.parse_color(color)
  if type(color) == 'number' then
    local hex = string.format('%06x', color)
    return {
      r = tonumber(hex:sub(1, 2), 16) or 255,
      g = tonumber(hex:sub(3, 4), 16) or 255,
      b = tonumber(hex:sub(5, 6), 16) or 255,
    }
  elseif type(color) == 'string' then
    local r, g, b = color:match '^#?(%x%x)(%x%x)(%x%x)$'
    if r then
      return {
        r = tonumber(r, 16) or 255,
        g = tonumber(g, 16) or 255,
        b = tonumber(b, 16) or 255,
      }
    end
  end
  return { r = 255, g = 255, b = 255 }
end

--- Read a highlight group's resolved `fg` or `bg` color as `#rrggbb`.
---@param group string
---@param attr 'fg'|'bg'
---@param fallback? string
---@return string|nil
function M.hl_hex(group, attr, fallback)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  local val = hl and hl[attr]
  if val then return string.format('#%06x', val) end
  return fallback
end

--- Compute perceptual brightness in [0, 1] from a `#rrggbb` string.
---@param hex? string
---@return number|nil
function M.hex_luminance(hex)
  local r, g, b = (hex or ''):match '^#(%x%x)(%x%x)(%x%x)$'
  if not r then return nil end
  return (0.299 * tonumber(r, 16) + 0.587 * tonumber(g, 16) + 0.114 * tonumber(b, 16)) / 255
end

--- Return true when `hex` is brighter than mid-gray.
---@param hex? string
---@param default_light? boolean
---@return boolean
function M.is_light_hex(hex, default_light)
  local lum = M.hex_luminance(hex)
  if lum == nil then return default_light ~= false end
  return lum > 0.5
end

--- Choose dark or light foreground hex color for contrast over `hex`.
---@param hex? string
---@param dark_fg? string
---@param light_fg? string
---@return string
function M.contrast_fg(hex, dark_fg, light_fg)
  local lum = M.hex_luminance(hex)
  if not lum then return light_fg or '#ffffff' end
  return lum > 0.55 and (dark_fg or '#181b1b') or (light_fg or '#ffffff')
end

local function srgb_to_oklab(c)
  local l = math.max(0, 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b) / 255
  local m = math.max(0, 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b) / 255
  local s = math.max(0, 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b) / 255

  local l_ = l ^ (1 / 3)
  local m_ = m ^ (1 / 3)
  local s_ = s ^ (1 / 3)

  return {
    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
    b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
  }
end

local function oklab_to_srgb(c)
  local l_ = c.L + 0.3963377774 * c.a + 0.2158037573 * c.b
  local m_ = c.L - 0.1055613458 * c.a - 0.0638541728 * c.b
  local s_ = c.L - 0.0894841775 * c.a - 1.2914855480 * c.b

  local l = l_ * l_ * l_
  local m = m_ * m_ * m_
  local s = s_ * s_ * s_

  return {
    r = clamp_byte((4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s) * 255),
    g = clamp_byte((-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s) * 255),
    b = clamp_byte((-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s) * 255),
  }
end

--- Blend `fg_color` onto `bg_color` in Oklab space with opacity `alpha` in [0, 1].
---@param fg_color number|string
---@param bg_color number|string
---@param alpha number
---@return string mixed_hex, string fg_hex, string bg_hex
function M.mix_oklab_hex(fg_color, bg_color, alpha)
  local fg_rgb = M.parse_color(fg_color)
  local bg_rgb = M.parse_color(bg_color)
  local fg_lab = srgb_to_oklab(fg_rgb)
  local bg_lab = srgb_to_oklab(bg_rgb)

  local mixed_rgb = oklab_to_srgb {
    L = fg_lab.L * alpha + bg_lab.L * (1 - alpha),
    a = fg_lab.a * alpha + bg_lab.a * (1 - alpha),
    b = fg_lab.b * alpha + bg_lab.b * (1 - alpha),
  }

  return M.rgb_to_hex(mixed_rgb.r, mixed_rgb.g, mixed_rgb.b),
    M.rgb_to_hex(fg_rgb.r, fg_rgb.g, fg_rgb.b),
    M.rgb_to_hex(bg_rgb.r, bg_rgb.g, bg_rgb.b)
end

--- Return a named Lua upvalue from `fn`, or nil if `fn` is not a function.
---@param fn any
---@param name string
---@return any
function M.get_upvalue(fn, name)
  if type(fn) ~= 'function' then return nil end
  local i = 1
  while true do
    local n, v = debug.getupvalue(fn, i)
    if not n then return nil end
    if n == name then return v end
    i = i + 1
  end
end

return M
