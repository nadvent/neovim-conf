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
  require('fidget').setup {}

  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
    callback = function(event)
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
            typeCheckingMode = 'standard', -- 'off' | 'basic' | 'standard' | 'strict' | 'all'
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

  require('mason').setup {}

  -- External Formatters, Linters, and Debug Adapters for Mason to auto-install
  local extra_tools = {
    -- Lua
    'stylua',
    -- 'selene',           -- Optional Lua linter

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
  }

  local ensure_installed = vim.tbl_keys(servers)
  vim.list_extend(ensure_installed, extra_tools)

  require('mason-tool-installer').setup {
    ensure_installed = ensure_installed,
    auto_update = false,
    run_on_start = true,
    start_delay = 3000, -- Delay check by 3 seconds after startup
  }

  require('mason-lspconfig').setup {
    automatic_enable = {
      -- Exclude servers managed by dedicated language plugins when you split them out:
      exclude = {
        'rust_analyzer', -- Uncomment when using mrcjkb/rustaceanvim
        -- 'jdtls',         -- Uncomment when using mfussenegger/nvim-jdtls
      },
    },
  }
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
  local lint = require 'lint'

  lint.linters_by_ft = {
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
      if vim.bo.modifiable then lint.try_lint() end
    end,
  })
end

-- ============================================================================
-- 5. AUTOCOMPLETE & SNIPPETS (blink.cmp + LuaSnip)
-- ============================================================================
do
  require('luasnip').setup {}

  vim.api.nvim_create_autocmd('InsertEnter', {
    once = true,
    callback = function() require('luasnip.loaders.from_vscode').lazy_load() end,
  })

  require('scissors').setup {
    snippetDir = '~/Documents/Snippets',
  }

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
      default = { 'lsp', 'path', 'snippets' },
      providers = {},
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
  local dap = require 'dap'
  local dap_view = require 'dap-view'

  -- Defer heavy debug adapter mappings until after the UI renders
  vim.schedule(function()
    require('mason-nvim-dap').setup {
      automatic_installation = true,
      handlers = {},
      ensure_installed = {
        'codelldb', -- C, C++, and Rust
        'python', -- Python (installs `debugpy`)
        'javadbg', -- Java (installs `java-debug-adapter`)
        'javatest', -- Java (installs `java-test`)
        'php', -- PHP (installs `php-debug-adapter` for Xdebug)
        -- 'cpptools', -- Alternative C/C++/Rust debugger (GDB/LLDB wrapper)
      },
    }

    dap_view.setup()

    dap.listeners.before.attach.dapview_config = function() dap_view.open() end
    dap.listeners.before.launch.dapview_config = function() dap_view.open() end
    dap.listeners.before.event_terminated.dapview_config = function() dap_view.close() end
    dap.listeners.before.event_exited.dapview_config = function() dap_view.close() end
  end)
end

-- ============================================================================
-- 7. AI & TASK RUNNER (sidekick.nvim + overseer.nvim)
-- ============================================================================
do
  require('sidekick').setup {
    cli = {
      mux = {
        backend = 'tmux',
        enabled = true,
      },
    },
  }

  require('overseer').setup {}
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
  require('nvim-treesitter').install(parsers)

  ---@param buf integer
  ---@param language string
  local function treesitter_try_attach(buf, language)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if not vim.treesitter.language.add(language) then return end

    vim.treesitter.start(buf, language)

    local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil
    if has_indent_query then vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
  end

  local available_parsers = require('nvim-treesitter').get_available()
  vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
      local buf, filetype = args.buf, args.match
      local language = vim.treesitter.language.get_lang(filetype)
      if not language then return end

      local installed_parsers = require('nvim-treesitter').get_installed 'parsers'
      if vim.tbl_contains(installed_parsers, language) then
        treesitter_try_attach(buf, language)
      elseif vim.tbl_contains(available_parsers, language) then
        require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
      else
        treesitter_try_attach(buf, language)
      end
    end,
  })
end
