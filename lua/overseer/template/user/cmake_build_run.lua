-- overseer/template/user/cmake_build_run.lua
local overseer = require 'overseer'

---@type overseer.TemplateFileDefinition
return {
  name = 'CMake: Build & Run',
  desc = 'Configure, compile, and execute CMake target with custom flags',
  params = {
    build_type = {
      type = 'enum',
      name = 'Build Type',
      default = 'Debug',
      choices = { 'Debug', 'Release', 'RelWithDebInfo' },
    },
    compiler = {
      type = 'enum',
      name = 'Compiler Toolchain',
      default = 'clang',
      choices = { 'clang', 'gcc' },
    },
    std = {
      type = 'enum',
      name = 'C++ Standard',
      default = '20',
      choices = { '17', '20', '23' },
    },
    sanitizers = {
      type = 'boolean',
      name = 'Enable ASan & UBSan',
      default = true,
      desc = 'AddressSanitizer and UndefinedBehaviorSanitizer',
    },
    target = {
      type = 'string',
      name = 'CMake Target',
      default = '',
      desc = 'Leave blank to build and run the default target',
    },
  },
  builder = function(params)
    local c_compiler = params.compiler == 'clang' and 'clang' or 'gcc'
    local cxx_compiler = params.compiler == 'clang' and 'clang++' or 'g++'
    local build_dir = 'build-' .. params.build_type:lower() .. '-' .. params.compiler

    local cxx_flags = '-std=c++' .. params.std
    if params.sanitizers and params.build_type == 'Debug' then cxx_flags = cxx_flags .. ' -fsanitize=address,undefined -fno-omit-frame-pointer' end

    local configure_cmd = string.format(
      'cmake -B %s -DCMAKE_BUILD_TYPE=%s -DCMAKE_C_COMPILER=%s -DCMAKE_CXX_COMPILER=%s -DCMAKE_CXX_FLAGS="%s"',
      build_dir,
      params.build_type,
      c_compiler,
      cxx_compiler,
      cxx_flags
    )

    local target_flag = params.target ~= '' and ('--target ' .. params.target) or ''
    local build_cmd = string.format('cmake --build %s %s', build_dir, target_flag)
    local run_cmd = string.format('./%s/%s', build_dir, params.target ~= '' and params.target or '$(basename "$PWD")')

    return {
      cmd = { 'bash', '-c', string.format('%s && %s && %s', configure_cmd, build_cmd, run_cmd) },
      components = {
        { 'on_output_quickfix', open = false },
        'on_complete_notify',
        'default',
      },
    }
  end,
  condition = {
    callback = function() return vim.fn.filereadable(vim.fn.getcwd() .. '/CMakeLists.txt') == 1 end,
  },
}
