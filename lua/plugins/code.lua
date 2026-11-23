local util = require 'core.util'

local M = {}

local gh = util.gh

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
  gh 'r4ppz/lspeek.nvim',
  gh 'not-manu/filemention.nvim',

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
  gh 'jay-babu/mason-nvim-dap.nvim',
  gh 'igorlfs/nvim-dap-view',

  -- AI & Task Runner
  gh 'folke/sidekick.nvim',
  gh 'nvim-lua/plenary.nvim',
  gh 'stevearc/overseer.nvim',
  gh 'zbirenbaum/copilot.lua',
  gh 'giuxtaposition/blink-cmp-copilot',
}

local state = {
  fidget = false,
  mason = false,
  luasnip = false,
  dap = false,
  copilot = false,
  ai_runner = false,
}

-- ============================================================================
-- 2. LSP (Language Server Protocol & Mason)
-- ============================================================================
do
  local function is_leetcode_root(config)
    local root = config.root_dir and vim.fs.normalize(config.root_dir) or ''
    return util.path_in_dir(root, util.PATHS.leetcode) or util.in_leetcode()
  end

  vim.api.nvim_create_autocmd('LspAttach', {
    group = util.augroup 'lsp_attach',
    callback = function(event)
      if not state.fidget then
        state.fidget = true
        pcall(function() require('fidget').setup {} end)
      end

      local map = function(keys, func, desc, mode) vim.keymap.set(mode or 'n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc }) end

      map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
      map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
      map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client:supports_method('textDocument/documentHighlight', event.buf) then
        local highlight_augroup = vim.api.nvim_create_augroup('nvim_lsp_highlight', { clear = false })
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
          group = util.augroup 'lsp_detach',
          callback = function(event2)
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds { group = 'nvim_lsp_highlight', buffer = event2.buf }
          end,
        })
      end

      if client and client:supports_method('textDocument/inlayHint', event.buf) then
        map('<leader>uh', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, 'UI: Toggle Inlay Hints')
      end
      if client and client:supports_method('textDocument/documentColor', event.buf) then vim.lsp.document_color.enable(true, { bufnr = event.buf }) end
    end,
  })

  ---@type table<string, vim.lsp.Config>
  local servers = {
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
    neocmake = {},

    basedpyright = {
      before_init = function(_, config)
        if is_leetcode_root(config) then
          config.settings = vim.tbl_deep_extend('force', config.settings or {}, {
            basedpyright = {
              analysis = {
                typeCheckingMode = 'basic',
                diagnosticSeverityOverrides = {
                  reportUnusedImport = 'none',
                  reportUnusedVariable = 'none',
                  reportUnusedExpression = 'none',
                  reportWildcardImportFromLibrary = 'none',
                  reportMissingImports = 'error',
                },
              },
            },
          })
        end
      end,
      settings = {
        basedpyright = {
          analysis = {
            typeCheckingMode = 'strict',
            disableOrganizeImports = true,
          },
        },
      },
    },

    ruff = {
      before_init = function(_, config)
        if is_leetcode_root(config) then
          config.init_options = vim.tbl_deep_extend('force', config.init_options or {}, {
            settings = {
              lineLength = 120,
              lint = {
                ignore = {
                  'E401',
                  'E402',
                  'E501',
                  'E701',
                  'E702',
                  'E731',
                  'E741',
                  'F401',
                  'F403',
                  'F405',
                  'F841',
                },
              },
            },
          })
        end
      end,
    },

    -- jdtls is started by nvim-lspconfig; plugins/opt/java.lua provides extra nvim-jdtls actions
    jdtls = {},

    -- rust_analyzer is managed by rustaceanvim in plugins/opt/rust.lua
    tinymist = {
      settings = {
        formatterMode = 'typstyle',
        exportPdf = 'onType',
      },
    },

    texlab = {},
    marksman = {},
    intelephense = {},

    cssls = {
      filetypes = { 'css', 'scss', 'less', 'html' },
    },

    lua_ls = {
      on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false
        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
        end
        local current_settings = client.config.settings --[[@as lspconfig.settings.lua_ls]]
        client.config.settings.Lua = vim.tbl_deep_extend('force', current_settings.Lua or {}, {
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

  for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
  end

  local extra_tools = {
    'stylua',
    'clang-format',
    'cpplint',
    'gersemi',
    'google-java-format',
    'checkstyle',
    'java-debug-adapter',
    'java-test',
    'typstyle',
    'tex-fmt',
    -- 'markdownlint-cli2',
    'prettierd',
    'pint',
    'phpstan',
    'emmet-language-server',
    'tailwindcss-language-server',
    'css-lsp',
  }

  local ensure_installed = vim.tbl_keys(servers)
  vim.list_extend(ensure_installed, extra_tools)

  --- Initialize Mason, mason-lspconfig, and mason-tool-installer on demand.
  function M.init_mason()
    if state.mason then return end
    state.mason = true
    require('mason').setup {}
    require('mason-tool-installer').setup {
      ensure_installed = ensure_installed,
      auto_update = false,
      run_on_start = true,
      start_delay = 0,
    }
    require('mason-lspconfig').setup {
      automatic_enable = {
        exclude = {
          'rust_analyzer',
          'copilot',
        },
      },
    }
  end

  vim.defer_fn(M.init_mason, 4000)

  for _, cmd in ipairs { 'Mason', 'MasonInstall', 'MasonUpdate', 'MasonLog' } do
    vim.api.nvim_create_user_command(cmd, function(opts)
      pcall(vim.api.nvim_del_user_command, cmd)
      M.init_mason()
      vim.cmd(cmd .. (opts.args ~= '' and (' ' .. opts.args) or ''))
    end, { nargs = '*' })
  end

  pcall(
    function()
      require('lspeek').setup {
        window = {
          width = 80,
          height = 18,
          border = 'rounded',
          win_opts = {
            number = true,
            relativenumber = false,
          },
        },
        stack_limit = 10,
        select_first = false,
      }
    end
  )
end

-- ============================================================================
-- 3. FORMATTING (conform.nvim)
-- ============================================================================
require('conform').setup {
  notify_on_error = false,
  format_on_save = function(bufnr)
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
    }
    if enabled_filetypes[vim.bo[bufnr].filetype] then return { timeout_ms = 500, lsp_format = 'fallback' } end
    return nil
  end,
  default_format_opts = {
    lsp_format = 'fallback',
  },
  formatters_by_ft = {
    lua = { 'stylua' },
    c = { 'clang-format' },
    cpp = { 'clang-format' },
    cmake = { 'gersemi' },
    python = { 'ruff_organize_imports', 'ruff_format' },
    java = { 'google-java-format' },
    rust = { 'rustfmt', lsp_format = 'fallback' },
    typst = { 'typstyle' },
    tex = { 'tex-fmt' },
    bib = { 'tex-fmt' },
    markdown = { 'prettierd', stop_after_first = true },
    php = { 'pint', 'php_cs_fixer', stop_after_first = true },
  },
  formatters = {
    typstyle = {
      args = { '--column', '80' },
    },
  },
}

-- ============================================================================
-- 4. LINTING (nvim-lint)
-- ============================================================================
do
  local linters_by_ft = {
    c = { 'cpplint' },
    cpp = { 'cpplint' },
    cmake = { 'cmakelint' },
    python = { 'ruff' },
    java = { 'checkstyle' },
    tex = { 'chktex' },
    -- markdown = { 'markdownlint-cli2' },
    php = { 'phpstan' },
  }

  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
    group = util.augroup 'nvim_lint',
    callback = function()
      if not vim.bo.modifiable then return end
      local ok, lint = pcall(require, 'lint')
      if not ok then return end
      if util.in_leetcode() and vim.bo.filetype == 'python' then return end
      lint.linters_by_ft = linters_by_ft
      lint.try_lint()
    end,
  })
end

-- ============================================================================
-- 5. AUTOCOMPLETE & SNIPPETS (blink.cmp + LuaSnip)
-- ============================================================================
do
  local function setup_luasnip()
    if state.luasnip then return end
    state.luasnip = true
    pcall(function()
      require('luasnip').setup {}
      require('luasnip.loaders.from_vscode').lazy_load()
    end)
    pcall(
      function()
        require('filemention').setup {
          trigger = '@',
          root = 'git',
          respect_gitignore = true,
          filetypes = { 'markdown', 'quarto', 'typst', 'tex', 'bib', 'text', 'gitcommit' },
          finder = 'auto',
        }
      end
    )
  end

  vim.api.nvim_create_autocmd('InsertEnter', {
    group = util.augroup 'luasnip_init',
    once = true,
    callback = setup_luasnip,
  })

  local function get_scissors()
    local ok, scissors = pcall(require, 'scissors')
    if ok then
      scissors.setup { snippetDir = util.PATHS.snippets }
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
      if vim.bo.omnifunc ~= 'v:lua.overseer_form_omnifunc' or not _G.overseer_form_omnifunc then
        callback { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
        return
      end

      local start_col = _G.overseer_form_omnifunc(1, '')
      if not start_col or start_col < 0 then
        callback { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
        return
      end

      local base = context.line:sub(start_col + 1, context.cursor[2])
      local results = _G.overseer_form_omnifunc(0, base)
      if not results or #results == 0 then
        callback { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
        return
      end

      local items = {}
      local enum_kind = require('blink.cmp.types').CompletionItemKind.EnumMember
      for _, item in ipairs(results) do
        local word = type(item) == 'string' and item or item.word
        local menu = (type(item) == 'table' and item.menu) and item.menu or 'Overseer'
        table.insert(items, {
          label = word,
          insertText = word,
          kind = enum_kind,
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
      default = { 'filemention', 'lsp', 'path', 'snippets', 'copilot', 'buffer', 'overseer' },
      providers = {
        filemention = {
          name = 'filemention',
          module = 'filemention.sources.blink',
          score_offset = 15,
        },
        copilot = {
          name = 'copilot',
          module = 'blink-cmp-copilot',
          async = true,
          enabled = function() return not util.in_leetcode() end,
        },
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
-- 6. DEBUGGING / DAP (nvim-dap + mason-nvim-dap + nvim-dap-view)
-- ============================================================================

--- Lazily initialize nvim-dap, mason-nvim-dap, and nvim-dap-view.
---@return table dap
function M.load_dap()
  if state.dap then return require 'dap' end
  state.dap = true

  local dap = require 'dap'
  local dap_view = require 'dap-view'

  require('mason-nvim-dap').setup {
    automatic_installation = true,
    handlers = {},
    ensure_installed = {
      'codelldb',
      'python',
      'javadbg',
      'javatest',
      'php',
    },
  }

  dap_view.setup()

  dap.listeners.before.attach.dapview_config = function() dap_view.open() end
  dap.listeners.before.launch.dapview_config = function() dap_view.open() end
  dap.listeners.before.event_terminated.dapview_config = function() dap_view.close() end
  dap.listeners.before.event_exited.dapview_config = function() dap_view.close() end

  return dap
end

for _, cmd in ipairs {
  'DapContinue',
  'DapToggleBreakpoint',
  'DapStepInto',
  'DapStepOver',
  'DapStepOut',
  'DapTerminate',
  'DapViewToggle',
  'DapViewOpen',
  'DapViewClose',
} do
  vim.api.nvim_create_user_command(cmd, function(opts)
    pcall(vim.api.nvim_del_user_command, cmd)
    M.load_dap()
    pcall(vim.cmd, cmd .. (opts.args ~= '' and (' ' .. opts.args) or ''))
  end, { nargs = '*' })
end

-- ============================================================================
-- 7. AI & TASK RUNNER (sidekick.nvim + copilot.lua + overseer.nvim)
-- ============================================================================
do
  local function init_copilot()
    if state.copilot or util.in_leetcode() then return end
    state.copilot = true
    pcall(
      function()
        require('copilot').setup {
          suggestions = {
            enabled = false,
            debounce = 400,
          },
          panel = { enabled = false },
        }
      end
    )
  end

  vim.api.nvim_create_autocmd('InsertEnter', {
    group = util.augroup 'copilot_init',
    once = true,
    callback = init_copilot,
  })

  local function init_ai_and_runner()
    if state.ai_runner then return end
    state.ai_runner = true

    local in_leetcode = util.in_leetcode()
    if not in_leetcode then init_copilot() end

    pcall(
      function()
        require('sidekick').setup {
          nes = {
            enabled = not in_leetcode,
          },
          copilot = {
            status = {
              enabled = not in_leetcode,
            },
          },
          cli = {
            mux = {
              backend = 'tmux',
              enabled = true,
            },
            tools = {
              antigravity = {
                cmd = { 'agy' },
              },
            },
          },
        }
      end
    )

    pcall(
      function()
        require('overseer').setup {
          form = {
            border = 'rounded',
            win_opts = {
              winblend = 0,
            },
          },
          task_launcher = {},
        }
      end
    )
  end

  vim.api.nvim_create_autocmd('UIEnter', {
    group = util.augroup 'ai_runner_init',
    once = true,
    callback = function() vim.defer_fn(init_ai_and_runner, 300) end,
  })
end

-- ============================================================================
-- 8. TREESITTER
-- ============================================================================
do
  local textobjects_ready = false

  ---@param buf integer
  ---@param language string
  ---@param refresh_folds? boolean
  local function treesitter_try_attach(buf, language, refresh_folds)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if not vim.treesitter.language.add(language) then return end

    if not textobjects_ready then
      textobjects_ready = true
      pcall(function()
        require('nvim-treesitter-textobjects').setup {
          select = { lookahead = true },
        }
      end)
    end

    vim.treesitter.start(buf, language)

    if vim.treesitter.query.get(language, 'indents') ~= nil then vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end

    if refresh_folds and vim.bo[buf].buftype == '' and vim.bo[buf].filetype ~= 'bigfile' then
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        if vim.api.nvim_win_is_valid(win) and vim.wo[win].foldmethod == 'expr' then pcall(vim.api.nvim_win_call, win, function() vim.cmd 'normal! zx' end) end
      end
    end
  end

  vim.api.nvim_create_autocmd('FileType', {
    group = util.augroup 'treesitter_attach',
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
          ts.install(language):await(function() treesitter_try_attach(buf, language, true) end)
          return
        end
      end

      treesitter_try_attach(buf, language)
    end,
  })
end

return M
