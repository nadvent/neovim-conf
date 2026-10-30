---@param repo string
---@return string
local function gh(repo) return 'https://github.com/' .. repo end

-- ============================================================================
-- 1. CORE CODING PLUGINS (Batched Installation)
-- ============================================================================
vim.pack.add {
  -- LSP & Package Management
  gh 'neovim/nvim-lspconfig',
  gh 'mason-org/mason.nvim',
  gh 'mason-org/mason-lspconfig.nvim',
  gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
  gh 'j-hui/fidget.nvim',

  -- Formatting & Linting
  gh 'stevearc/conform.nvim',
  gh 'mfussenegger/nvim-lint',

  -- Autocompletion & Snippets
  { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' },
  gh 'rafamadriz/friendly-snippets',
  gh 'chrisgrieser/nvim-scissors',
  { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' },

  -- Treesitter
  { src = gh 'nvim-treesitter/nvim-treesitter', version = 'main' },
  gh 'nvim-treesitter/nvim-treesitter-textobjects',

  -- Debugging (DAP)
  gh 'mfussenegger/nvim-dap',
  gh 'nvim-neotest/nvim-nio',
  gh 'jay-babu/mason-nvim-dap.nvim',
  gh 'igorlfs/nvim-dap-view',

  -- AI & Task Runner
  gh 'folke/sidekick.nvim',
  gh 'nvim-lua/plenary.nvim',
  gh 'stevearc/overseer.nvim',
}

-- ============================================================================
-- 2. LSP (Language Server Protocol & Mason)
-- ============================================================================
do
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
    callback = function(event)
      if not _G._fidget_loaded then
        _G._fidget_loaded = true
        pcall(function() require('fidget').setup {} end)
      end

      local map = function(keys, func, desc, mode)
        mode = mode or 'n'
        vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
      end

      map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
      map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
      map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client:supports_method('textDocument/documentHighlight', event.buf) then
        local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = event.buf,
          group = highlight_augroup,
          callback = vim.lsp.buf.clear_references,
        })
        vim.api.nvim_create_autocmd('LspDetach', {
          group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
          callback = function(event2)
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
          end,
        })
      end

      if client and client:supports_method('textDocument/inlayHint', event.buf) then
        map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
      end
      if client and client:supports_method('textDocument/documentColor', event.buf) then vim.lsp.document_color.enable(true, { bufnr = event.buf }) end
    end,
  })

  ---@type table<string, vim.lsp.Config>
  local servers = {
    -- [[ C & C++ ]]
    clangd = {
      cmd = {
        'clangd',
        '--background-index',
        '--clang-tidy',
        '--header-insertion=iwyu',
        '--completion-style=detailed',
        '--function-arg-placeholders',
        '--fallback-style=llvm',
      },
    },
    neocmake = {}, -- Optional: LSP for CMakeLists.txt

    -- [[ Python ]]
    -- Option 1: basedpyright (fast type checking) + ruff (linting, imports, hover)
    basedpyright = {
      settings = {
        basedpyright = {
          analysis = {
            typeCheckingMode = 'strict', -- 'off' | 'basic' | 'standard' | 'strict' | 'all'
            disableOrganizeImports = true, -- Let Ruff handle import sorting
          },
        },
      },
    },
    ruff = {},
    -- Option 2: pyright = {},
    -- Option 3: pylsp = {},

    -- [[ Java ]]
    -- NOTE: If you use `mfussenegger/nvim-jdtls` in your separate java.lua file,
    -- comment out `jdtls` here so nvim-lspconfig doesn't launch a duplicate server.
    jdtls = {},

    -- [[ Rust ]]
    -- NOTE: If you use `mrcjkb/rustaceanvim` in your separate rust.lua file,
    -- comment out `rust_analyzer` here! rustaceanvim manages the LSP lifecycle itself.
    -- rust_analyzer = {
    --   settings = {
    --     ['rust-analyzer'] = {
    --       checkOnSave = true,
    --       check = { command = 'clippy' },
    --     },
    --   },
    -- },

    -- [[ Typst ]]
    tinymist = {
      settings = {
        formatterMode = 'typstyle', -- 'typstyle' | 'prettypst' | 'disable'
        exportPdf = 'onType', -- 'never' | 'onSave' | 'onType'
      },
    },

    -- [[ LaTeX ]]
    texlab = {},

    -- [[ Markdown ]]
    marksman = {},

    -- [[ PHP ]]
    intelephense = {},

    -- [[HTML]]
    cssls = {
      filetypes = { 'css', 'scss', 'less', 'html' },
    },

    -- [[ Lua (Neovim Config) ]]
    lua_ls = {
      on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false
        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
        end
        local current_settings = client.config.settings --[[@as lspconfig.settings.lua_ls]]
        client.config.settings.Lua = vim.tbl_deep_extend('force', current_settings.Lua, {
          runtime = {
            version = 'LuaJIT',
            path = { 'lua/?.lua', 'lua/?/init.lua' },
          },
          workspace = {
            checkThirdParty = false,
            library = vim.api.nvim_get_runtime_file('', true),
          },
        })
      end,
      ---@type lspconfig.settings.lua_ls
      settings = {
        Lua = {
          format = { enable = false },
        },
      },
    },
  }

  -- Register LSP configurations before enabling
  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end

  -- External Formatters, Linters, and Debug Adapters for Mason to auto-install
  local extra_tools = {
    -- Lua
    'stylua',

    -- C / C++
    'clang-format',
    'cpplint',
    'gersemi', -- CMake formatter

    -- Java
    'google-java-format',
    'checkstyle',
    'java-debug-adapter',
    'java-test',

    -- Typst
    'typstyle',

    -- LaTeX
    'tex-fmt', -- Fast Rust-based LaTeX formatter

    -- Markdown
    'markdownlint-cli2', -- Fast Markdown linter & formatter
    'prettierd', -- Used for Markdown (and web filetypes)

    -- PHP
    'pint', -- Laravel Pint (zero-config PHP-CS-Fixer wrapper)
    'phpstan', -- PHP static analysis linter

    -- HTML
    'emmet-language-server', -- Tags
    'tailwindcss-language-server',
    'css-lsp',
  }

  local ensure_installed = vim.tbl_keys(servers)
  vim.list_extend(ensure_installed, extra_tools)

  local function init_mason()
    if _G._mason_initialized then return end
    _G._mason_initialized = true
    require('mason').setup {}
    require('mason-tool-installer').setup {
      ensure_installed = ensure_installed,
      auto_update = false,
      run_on_start = true,
      start_delay = 1000,
    }
    require('mason-lspconfig').setup {
      automatic_enable = {
        exclude = {
          'rust_analyzer',
        },
      },
    }
  end

  _G.init_mason = init_mason
  vim.defer_fn(init_mason, 4000)

  vim.api.nvim_create_user_command('Mason', function()
    init_mason()
    vim.cmd 'Mason'
  end, {})
end

-- ============================================================================
-- 3. FORMATTING (conform.nvim)
-- ============================================================================
do
  require('conform').setup {
    notify_on_error = false,
    format_on_save = function(bufnr)
      -- Enable or disable format-on-save per filetype
      local enabled_filetypes = {
        lua = true,
        c = true,
        cpp = true,
        python = true,
        rust = true,
        typst = true,
        tex = true,
        markdown = true,
        php = true,
        -- java = true,
      }
      if enabled_filetypes[vim.bo[bufnr].filetype] then return { timeout_ms = 500, lsp_format = 'fallback' } end
      return nil
    end,
    default_format_opts = {
      lsp_format = 'fallback',
    },
    formatters_by_ft = {
      -- Lua
      lua = { 'stylua' },

      -- C & C++
      c = { 'clang-format' },
      cpp = { 'clang-format' },
      cmake = { 'gersemi' },

      -- Python
      python = { 'ruff_organize_imports', 'ruff_format' },

      -- Java
      java = { 'google-java-format' },
      -- Option 2: java = { 'clang-format' }, -- Or rely on jdtls LSP formatting

      -- Rust (rustfmt is installed via `rustup`, not Mason)
      rust = { 'rustfmt', lsp_format = 'fallback' },

      -- Typst
      typst = { 'typstyle' },

      -- LaTeX
      tex = { 'tex-fmt' },
      bib = { 'tex-fmt' },

      -- Markdown
      markdown = { 'prettierd', 'markdownlint-cli2', stop_after_first = true },

      -- PHP
      php = { 'pint', 'php_cs_fixer', stop_after_first = true },
    },
  }

  vim.keymap.set({ 'n', 'v' }, '<leader>f', function() require('conform').format { async = true, lsp_format = 'fallback' } end, { desc = '[F]ormat buffer' })
end

-- ============================================================================
-- 4. LINTING (nvim-lint)
-- ============================================================================
do
  local linters_by_ft = {
    -- C & C++ (Optional extra style check alongside clangd's built-in clang-tidy)
    c = { 'cpplint' },
    cpp = { 'cpplint' },
    cmake = { 'cmakelint' },

    -- Python (Can run alongside ruff LSP, or add 'mypy' for strict type linting)
    python = { 'ruff' },

    -- Java
    java = { 'checkstyle' },

    tex = { 'chktex' },

    -- Markdown
    markdown = { 'markdownlint-cli2' },

    -- PHP
    php = { 'phpstan' },

    -- Lua
  }

  local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
    group = lint_augroup,
    callback = function()
      if vim.bo.modifiable then
        local ok, lint = pcall(require, 'lint')
        if ok then
          lint.linters_by_ft = linters_by_ft
          lint.try_lint()
        end
      end
    end,
  })
end

-- ============================================================================
-- 5. AUTOCOMPLETE & SNIPPETS (blink.cmp + LuaSnip)
-- ============================================================================
do
  local function setup_luasnip()
    if _G._luasnip_setup then return end
    _G._luasnip_setup = true
    pcall(function()
      require('luasnip').setup {}
      require('luasnip.loaders.from_vscode').lazy_load()
    end)
  end

  vim.api.nvim_create_autocmd('InsertEnter', {
    once = true,
    callback = setup_luasnip,
  })

  local function get_scissors()
    local ok, scissors = pcall(require, 'scissors')
    if ok then
      scissors.setup { snippetDir = '~/Documents/Snippets' }
      return scissors
    end
  end

  vim.api.nvim_create_user_command('ScissorsAddNewSnippet', function()
    local s = get_scissors()
    if s then s.addNewSnippet() end
  end, {})
  vim.api.nvim_create_user_command('ScissorsEditSnippet', function()
    local s = get_scissors()
    if s then s.editSnippet() end
  end, {})

  package.preload['blink-overseer'] = function()
    local provider = {}

    function provider.new() return setmetatable({}, { __index = provider }) end

    function provider:get_completions(context, callback)
      -- Only run if the buffer has Overseer's omnifunc
      if vim.bo.omnifunc ~= 'v:lua.overseer_form_omnifunc' or not _G.overseer_form_omnifunc then
        callback { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
        return
      end

      -- Call Overseer's omnifunc in findstart mode (1)
      local start_col = _G.overseer_form_omnifunc(1, '')
      if not start_col or start_col < 0 then
        callback { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
        return
      end

      -- Extract current text typed after the field label
      local line = context.line
      local cursor_col = context.cursor[2]
      local base = line:sub(start_col + 1, cursor_col)

      -- Call Overseer's omnifunc in search mode (0)
      local results = _G.overseer_form_omnifunc(0, base)
      if not results or #results == 0 then
        callback { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
        return
      end

      -- Map Overseer results to Blink completion items
      local items = {}
      for _, item in ipairs(results) do
        local word = type(item) == 'string' and item or item.word
        local menu = (type(item) == 'table' and item.menu) and item.menu or 'Overseer'
        table.insert(items, {
          label = word,
          insertText = word,
          kind = require('blink.cmp.types').CompletionItemKind.EnumMember,
          detail = menu,
        })
      end

      callback {
        is_incomplete_forward = false,
        is_incomplete_backward = false,
        items = items,
      }
    end

    return provider
  end

  require('blink.cmp').setup {
    keymap = {
      preset = 'enter',
      ['<Tab>'] = {
        'select_next',
        'snippet_forward',
        function()
          if require('sidekick').nes_jump_or_apply() then return true end
        end,
        function()
          if vim.lsp.inline_completion.get() then return true end
        end,
        'fallback',
      },
      ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
    },
    appearance = {
      nerd_font_variant = 'mono',
    },
    completion = {
      documentation = { auto_show = false, auto_show_delay_ms = 500 },
      list = { selection = { preselect = false } },
      ghost_text = { enabled = true },
    },
    sources = {
      default = { 'lsp', 'path', 'snippets', 'overseer' },
      providers = {
        overseer = {
          name = 'Overseer',
          module = 'blink-overseer',
          score_offset = 100,
          enabled = function() return vim.bo.omnifunc == 'v:lua.overseer_form_omnifunc' end,
        },
      },
    },
    snippets = { preset = 'luasnip' },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
    signature = { enabled = true },
  }
end

-- ============================================================================
-- 6. DEBUGGING / DAP (nvim-dap + mason-nvim-dap)
-- ============================================================================
do
  _G.load_dap = function()
    if _G._dap_loaded then return require 'dap' end
    _G._dap_loaded = true

    local dap = require 'dap'
    local dap_view = require 'dap-view'

    require('mason-nvim-dap').setup {
      automatic_installation = true,
      handlers = {},
      ensure_installed = {
        'codelldb', -- C, C++, and Rust
        'python', -- Python (installs `debugpy`)
        'javadbg', -- Java (installs `java-debug-adapter`)
        'javatest', -- Java (installs `java-test`)
        'php', -- PHP (installs `php-debug-adapter` for Xdebug)
      },
    }

    dap_view.setup()

    dap.listeners.before.attach.dapview_config = function() dap_view.open() end
    dap.listeners.before.launch.dapview_config = function() dap_view.open() end
    dap.listeners.before.event_terminated.dapview_config = function() dap_view.close() end
    dap.listeners.before.event_exited.dapview_config = function() dap_view.close() end

    return dap
  end

  for _, cmd in ipairs { 'DapContinue', 'DapToggleBreakpoint', 'DapStepInto', 'DapStepOver', 'DapStepOut', 'DapTerminate', 'DapView' } do
    vim.api.nvim_create_user_command(cmd, function(opts)
      _G.load_dap()
      pcall(vim.cmd, cmd .. ' ' .. (opts.args or ''))
    end, { nargs = '*' })
  end
end

-- ============================================================================
-- 7. AI & TASK RUNNER (sidekick.nvim + overseer.nvim)
-- ============================================================================
do
  local function init_ai_and_runner()
    if _G._ai_runner_init then return end
    _G._ai_runner_init = true

    pcall(function()
      require('sidekick').setup {
        cli = {
          mux = {
            backend = 'tmux',
            enabled = true,
          },
        },
      }
    end)

    pcall(function()
      require('overseer').setup {
        form = {
          border = 'rounded',
          win_opts = {
            winblend = 0,
          },
        },
        task_launcher = {},
      }
    end)
  end

  _G.init_ai_and_runner = init_ai_and_runner

  vim.api.nvim_create_autocmd('UIEnter', {
    once = true,
    callback = function()
      vim.defer_fn(init_ai_and_runner, 300)
    end,
  })
end

-- ============================================================================
-- 8. TREESITTER
-- ============================================================================
do
  local parsers = {
    -- Core & Config
    'bash',
    'diff',
    'lua',
    'luadoc',
    'query',
    'vim',
    'vimdoc',
    'toml',
    'json',
    'yaml',
    'regex',

    -- Target Languages
    'c',
    'cpp',
    'cmake',
    'python',
    'java',
    'rust',
    'typst',
    'latex',
    'bibtex',
    'markdown',
    'markdown_inline',
    'html',
    'php',
    'phpdoc',
  }

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if not vim.treesitter.language.add(language) then return end

    vim.treesitter.start(buf, language)

    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
    if has_indent_query then vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match
      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end

      if pcall(vim.treesitter.language.add, language) then
        treesitter_try_attach(buf, language)
        return
      end

      local ok, ts = pcall(require, 'nvim-treesitter')
      if ok then
        local available = ts.get_available()
        if vim.tbl_contains(available, language) then
          ts.install(language):await(function() treesitter_try_attach(buf, language) end)
        else
          treesitter_try_attach(buf, language)
        end
      else
        treesitter_try_attach(buf, language)
      end
    end,
  })
end
