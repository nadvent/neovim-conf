local function has_venv()
  local cwd = vim.fn.getcwd()
  local venv_python = vim.fs.joinpath(cwd, '.venv', 'bin', 'python')
  local venv_dir = vim.fs.joinpath(cwd, '.venv')
  return (vim.fn.executable 'uv' == 1 and (vim.fn.filereadable(venv_python) == 1 or vim.fn.isdirectory(venv_dir) == 1))
end

---@type overseer.TemplateFileProvider
return {
  generator = function(search, cb)
    local templates = {
      {
        name = 'uv: Run Current File',
        desc = 'Run current Python file using uv run',
        builder = function(params)
          local file = vim.fn.expand '%:p'
          local rel_file = vim.fn.expand '%:.'
          local cmd = { 'uv', 'run', file }
          if params.extra_args and params.extra_args ~= '' then
            for arg in string.gmatch(params.extra_args, '%S+') do
              table.insert(cmd, arg)
            end
          end
          return {
            cmd = cmd,
            name = 'uv run ' .. rel_file,
            components = {
              { 'on_output_quickfix', open = false },
              'on_complete_notify',
              'default',
            },
          }
        end,
        params = {
          extra_args = {
            type = 'string',
            name = 'Extra Arguments (Optional)',
            default = '',
            optional = true,
          },
        },
        condition = {
          filetype = { 'python' },
        },
        priority = 65,
      },
      {
        name = 'uv: Sync Dependencies',
        desc = 'Sync virtual environment with lockfile (uv sync)',
        builder = function(params)
          local cmd = { 'uv', 'sync' }
          if params.all_extras then table.insert(cmd, '--all-extras') end
          return {
            cmd = cmd,
            name = 'uv sync',
            components = {
              { 'on_output_quickfix', open = false },
              'on_complete_notify',
              'default',
            },
          }
        end,
        params = {
          all_extras = {
            type = 'boolean',
            name = 'Include All Extras (--all-extras)',
            default = false,
          },
        },
        priority = 60,
      },
      {
        name = 'uv: Add / Install Package',
        desc = 'Add package to project (uv add <package>)',
        builder = function(params)
          local cmd = { 'uv', 'add' }
          if params.dev then table.insert(cmd, '--dev') end
          table.insert(cmd, params.package)
          return {
            cmd = cmd,
            name = 'uv add ' .. params.package,
            components = {
              { 'on_output_quickfix', open = false },
              'on_complete_notify',
              'default',
            },
          }
        end,
        params = {
          package = {
            type = 'string',
            name = 'Package Name',
            order = 1,
          },
          dev = {
            type = 'boolean',
            name = 'Development Dependency (--dev)',
            default = false,
            order = 2,
          },
        },
        priority = 55,
      },
      {
        name = 'uv: Freeze Dependencies',
        desc = 'Export installed dependencies (uv pip freeze)',
        builder = function()
          return {
            cmd = { 'uv', 'pip', 'freeze' },
            name = 'uv pip freeze',
            components = {
              'on_output_summarize',
              'on_complete_notify',
              'default',
            },
          }
        end,
        priority = 50,
      },
      {
        name = 'uv: Run Tests (pytest)',
        desc = 'Run tests with uv run pytest',
        builder = function(params)
          local cmd = { 'uv', 'run', 'pytest' }
          if params.args and params.args ~= '' then
            for arg in string.gmatch(params.args, '%S+') do
              table.insert(cmd, arg)
            end
          end
          return {
            cmd = cmd,
            name = 'uv run pytest',
            components = {
              { 'on_output_quickfix', open = false },
              'on_complete_notify',
              'default',
            },
          }
        end,
        params = {
          args = {
            type = 'string',
            name = 'Pytest Arguments (e.g. -v -k test_name)',
            default = '-v',
            optional = true,
          },
        },
        priority = 45,
      },
      {
        name = 'uv: Lock / Update Lockfile',
        desc = 'Generate or update uv.lock (uv lock)',
        builder = function(params)
          local cmd = { 'uv', 'lock' }
          if params.upgrade then table.insert(cmd, '--upgrade') end
          return {
            cmd = cmd,
            name = 'uv lock',
            components = {
              { 'on_output_quickfix', open = false },
              'on_complete_notify',
              'default',
            },
          }
        end,
        params = {
          upgrade = {
            type = 'boolean',
            name = 'Upgrade all packages (--upgrade)',
            default = false,
          },
        },
        priority = 40,
      },
    }

    cb(templates)
  end,
  condition = {
    callback = has_venv,
  },
}
