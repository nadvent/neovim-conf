-- overseer/template/user/cpp_build_run.lua
local overseer = require 'overseer'

return {
  name = 'Single File: Compile & Run',
  desc = 'Compile current C/C++ file with compiler and debug flag choices',
  params = {
    compiler = {
      type = 'enum',
      name = 'Compiler',
      default = 'clang++',
      choices = { 'clang++', 'g++', 'clang', 'gcc' },
    },
    std = {
      type = 'enum',
      name = 'Standard',
      default = 'c++20',
      choices = { 'c++17', 'c++20', 'c++23', 'c11', 'c17' },
    },
    debug_flags = {
      type = 'enum',
      name = 'Debug Mode',
      default = 'Debug + Sanitizers',
      choices = {
        'Debug (-g -O0)',
        'Debug + Sanitizers (-g -O0 -fsanitize=address,undefined)',
        'Release (-O3)',
      },
    },
  },
  builder = function(params)
    local file = vim.fn.expand '%:p'
    local out = vim.fn.expand '%:p:r'

    local flags = { '-std=' .. params.std, '-Wall', '-Wextra' }
    if params.debug_flags == 'Debug (-g -O0)' then
      vim.list_extend(flags, { '-g', '-O0' })
    elseif params.debug_flags == 'Debug + Sanitizers (-g -O0 -fsanitize=address,undefined)' then
      vim.list_extend(flags, { '-g', '-O0', '-fsanitize=address,undefined', '-fno-omit-frame-pointer' })
    else
      table.insert(flags, '-O3')
    end

    local compile_args = { params.compiler, file, '-o', out }
    vim.list_extend(compile_args, flags)

    return {
      cmd = { 'bash', '-c', table.concat(compile_args, ' ') .. ' && ' .. out },
      components = {
        { 'on_output_quickfix', open = false },
        'on_complete_notify',
        'default',
      },
    }
  end,
  condition = {
    filetype = { 'c', 'cpp' },
  },
}
