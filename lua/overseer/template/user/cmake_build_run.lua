local function get_cmake_targets()
  local targets = {}
  local cmakelists = vim.fs.joinpath(vim.fn.getcwd(), 'CMakeLists.txt')
  if vim.fn.filereadable(cmakelists) == 1 then
    for line in io.lines(cmakelists) do
      local target = line:match 'add_executable%s*%(%s*([%w_%-]+)'
      if target and not vim.tbl_contains(targets, target) then table.insert(targets, target) end
    end
  end
  return targets
end

local function create_builder()
  return function(params)
    local c_comp = params.compiler == 'clang' and 'clang' or 'gcc'
    local cxx_comp = params.compiler == 'clang' and 'clang++' or 'g++'
    local b_type = params.build_type:find 'Release' and 'Release' or 'Debug'
    local build_dir = string.format('build-%s-%s', b_type:lower(), params.compiler)

    local cxx_flags = '-std=c++' .. params.std
    if params.build_type:find 'ASan' then cxx_flags = cxx_flags .. ' -fsanitize=address,undefined -fno-omit-frame-pointer' end
    if params.extra_flags and params.extra_flags ~= '' then cxx_flags = cxx_flags .. ' ' .. params.extra_flags end

    local configure_cmd = string.format(
      'cmake -B %s -DCMAKE_BUILD_TYPE=%s -DCMAKE_C_COMPILER=%s -DCMAKE_CXX_COMPILER=%s -DCMAKE_CXX_FLAGS="%s"',
      build_dir,
      b_type,
      c_comp,
      cxx_comp,
      cxx_flags
    )
    local build_cmd = string.format('cmake --build %s --target %s', build_dir, params.target)
    local run_cmd = string.format('./%s/%s', build_dir, params.target)

    return {
      cmd = { 'bash', '-c', string.format('%s && %s && %s', configure_cmd, build_cmd, run_cmd) },
      components = {
        { 'on_output_quickfix', open = false },
        'on_complete_notify',
        'default',
      },
    }
  end
end

---@type overseer.TemplateFileProvider
return {
  generator = function(search, cb)
    local targets = get_cmake_targets()
    local target_choices = #targets > 0 and targets or { 'main' }
    local default_target = target_choices[1]

    local shared_params = {
      target = {
        type = 'enum',
        name = 'CMake Target',
        choices = target_choices,
        order = 1,
      },
      compiler = {
        type = 'enum',
        name = 'Compiler',
        choices = { 'clang', 'gcc' },
        order = 2,
      },
      std = {
        type = 'enum',
        name = 'C++ Standard',
        choices = { '20', '17', '23' },
        order = 3,
      },
      build_type = {
        type = 'enum',
        name = 'Build Type',
        choices = {
          'Debug (plain -g)',
          'Debug (with ASan & UBSan)',
          'Release (-O3)',
          'RelWithDebInfo (-O2 -g)',
        },
        order = 4,
      },
      extra_flags = {
        type = 'string',
        name = 'Extra Flags (Optional)',
        default = '',
        optional = true,
        order = 5,
      },
    }

    local quick_params = vim.deepcopy(shared_params)
    quick_params.target.default = default_target
    quick_params.compiler.default = 'clang'
    quick_params.std.default = '20'
    quick_params.build_type.default = 'Debug (plain -g)'

    local templates = {
      {
        name = 'CMake: Quick Build & Run',
        desc = 'Build and run using defaults',
        params = quick_params,
        builder = create_builder(),
        priority = 60, -- Higher priority to show first
      },
      {
        name = 'CMake: Custom Build & Run',
        desc = 'Prompt to configure target, toolchain, and build flags',
        params = shared_params,
        builder = create_builder(),
        priority = 50,
      },
    }

    cb(templates)
  end,
  condition = {
    callback = function() return vim.fn.filereadable(vim.fs.joinpath(vim.fn.getcwd(), 'CMakeLists.txt')) == 1 end,
  },
}
