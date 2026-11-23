local util = require 'core.util'

local function run_build(name, cmd, cwd)
  local result = vim.system(cmd, { cwd = cwd }):wait()
  if result.code ~= 0 then
    local stderr = result.stderr or ''
    local stdout = result.stdout or ''
    local output = stderr ~= '' and stderr or stdout
    if output == '' then output = 'No output from build command.' end
    vim.notify(('Build failed for %s:\n%s'):format(name, output), vim.log.levels.ERROR)
  end
end

-- Runs after a plugin is installed or updated; must be registered before the first vim.pack.add().
-- See `:help vim.pack-events`
vim.api.nvim_create_autocmd('PackChanged', {
  group = util.augroup 'pack_hooks',
  callback = function(ev)
    local name = ev.data.spec.name
    local kind = ev.data.kind
    if kind ~= 'install' and kind ~= 'update' then return end

    if name == 'LuaSnip' then
      if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then run_build(name, { 'make', 'install_jsregexp' }, ev.data.path) end
      return
    end

    if name == 'nvim-treesitter' then
      if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
      vim.cmd 'TSUpdate'
      return
    end

    if name == 'vellum.nvim' then
      local render_dir = ev.data.path .. '/render'
      if vim.fn.executable 'npm' == 1 then
        run_build(name, { 'npm', 'ci' }, render_dir)
        run_build(name, { 'npx', 'puppeteer', 'browsers', 'install', 'chrome-headless-shell' }, render_dir)
      else
        vim.notify('vellum.nvim: npm not found; skipping diagram renderer install', vim.log.levels.WARN)
      end
      return
    end

    if name == 'math-conceal.nvim' then
      if vim.fn.executable 'cargo' == 1 then
        run_build(name, { 'cargo', 'build', '--release', '--manifest-path', 'service/Cargo.toml' }, ev.data.path)
      else
        vim.notify('math-conceal.nvim: cargo not found; cannot compile render service', vim.log.levels.WARN)
      end
      return
    end

    if name == 'real-icons.nvim' then
      if not ev.data.active then vim.cmd.packadd 'real-icons.nvim' end
      local ok, err = pcall(vim.cmd, 'RealIcons install')
      if not ok then vim.notify('real-icons.nvim install failed: ' .. tostring(err), vim.log.levels.WARN) end
      return
    end
  end,
})
