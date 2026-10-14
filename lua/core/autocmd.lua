  -- [[ Basic Autocommands ]]
  --  See `:help lua-guide-autocommands`
  -- See `:help vim.pack-events`

  local function augroup(name)
    return vim.api.nvim_create_augroup("vim_" .. name, { clear = true })
  end

  vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('highlight_yank', { clear = true }),
    callback = function() vim.hl.on_yank() end,
  })


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

  vim.api.nvim_create_autocmd('PackChanged', {
      callback = function(ev)
        local name = ev.data.spec.name
        local kind = ev.data.kind
        if kind ~= 'install' and kind ~= 'update' then return end

        if name == 'telescope-fzf-native.nvim' and vim.fn.executable 'make' == 1 then
          run_build(name, { 'make' }, ev.data.path)
          return
        end

        if name == 'LuaSnip' then
          if vim.fn.has 'win32' ~= 1 and vim.fn.executable 'make' == 1 then run_build(name, { 'make', 'install_jsregexp' }, ev.data.path) end
          return
        end

        if name == 'nvim-treesitter' then
          if not ev.data.active then vim.cmd.packadd 'nvim-treesitter' end
          vim.cmd 'TSUpdate'
          return
        end
      end,
    })


  -- resize splits if window got resized
  vim.api.nvim_create_autocmd({ "VimResized" }, {
    group = augroup("resize_splits"),
    callback = function()
      local current_tab = vim.fn.tabpagenr()
      vim.cmd("tabdo wincmd =")
      vim.cmd("tabnext " .. current_tab)
    end,
  })

  -- close some filetypes with <q>
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("close_with_q"),
    pattern = {
      "PlenaryTestPopup",
      "checkhealth",
      "dap-float",
      "dbout",
      "gitsigns-blame",
      "grug-far",
      "help",
      "lspinfo",
      "neotest-output",
      "neotest-output-panel",
      "neotest-summary",
      "notify",
      "qf",
      "spectre_panel",
      "startuptime",
      "tsplayground",
    },
    callback = function(event)
      vim.bo[event.buf].buflisted = false
      vim.schedule(function()
        vim.keymap.set("n", "q", function()
          vim.cmd("close")
          pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
        end, {
          buffer = event.buf,
          silent = true,
          desc = "Quit buffer",
        })
      end)
    end,
  })

  -- make it easier to close man-files when opened inline
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("man_unlisted"),
    pattern = { "man" },
    callback = function(event)
      vim.bo[event.buf].buflisted = false
    end,
  })

  -- wrap and check for spell in text filetypes
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("wrap_spell"),
    pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
    callback = function()
      vim.opt_local.wrap = true
      vim.opt_local.spell = true
    end,
  })

  -- Fix conceallevel for json files
  vim.api.nvim_create_autocmd({ "FileType" }, {
    group = augroup("json_conceal"),
    pattern = { "json", "jsonc", "json5" },
    callback = function()
      vim.opt_local.conceallevel = 0
    end,
  })

  -- Auto create dir when saving a file, in case some intermediate directory does not exist
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = augroup("auto_create_dir"),
    callback = function(event)
      if event.match:match("^%w%w+:[\\/][\\/]") then
        return
      end
      local file = vim.uv.fs_realpath(event.match) or event.match
      vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
    end,
  })
