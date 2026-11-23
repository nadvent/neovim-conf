local util = require 'core.util'

local M = {}

local initialized = false

local function get_proj_dir()
  if util.in_gspread(false) then return vim.fs.normalize(vim.fn.getcwd()) end
  return util.PATHS.gspread
end

local function run_cmd(args, on_success)
  local proj_dir = get_proj_dir()
  vim.notify('Executing: ' .. table.concat(args, ' '), vim.log.levels.INFO, { title = 'Google Sheets' })

  vim.system(args, { cwd = proj_dir }, function(res)
    vim.schedule(function()
      if res.code == 0 then
        if on_success then
          on_success(res.stdout or '')
        else
          local msg = (res.stdout and res.stdout ~= '') and res.stdout or 'Operation completed successfully.'
          vim.notify(msg, vim.log.levels.INFO, { title = 'Google Sheets' })
        end
      else
        local err = (res.stderr and res.stderr ~= '') and res.stderr or res.stdout
        vim.notify(err or 'Command failed', vim.log.levels.ERROR, { title = 'Google Sheets Error' })
      end
    end)
  end)
end

local EXPENSE_CATEGORIES = {
  'Food: Groceries',
  'Food: Dining Out & Cafes',
  'Food: Delivery & Takeaway',
  'Housing: Rent / Mortgage',
  'Housing: Home Maintenance',
  'Utilities: Water & Electric',
  'Utilities: Internet & Mobile',
  'Transport: Fuel & Parking',
  'Transport: Public Transit',
  'Transport: Vehicle Maintenance',
  'Shopping: Gadgets & Tech',
  'Shopping: Clothes & Apparel',
  'Subscriptions: Streaming & Apps',
  'Entertainment: Movies & Events',
  'Entertainment: Games & Hobbies',
  'Personal Care: Grooming & Spa',
  'Healthcare: Medical & Dental',
  'Insurance: Health & Life',
  'Travel: Trips & Staycations',
  'Social: Gifts & Celebrations',
  'Emergency Fund',
  'Investments: Stocks & ETFs',
  'Debt: Credit Card & Loans',
}

local INCOME_CATEGORIES = {
  'Salary & Wages',
  'Bonus & Incentives',
  'Freelance & Side Projects',
  'Dividends & Interest',
  'Refunds & Reimbursements',
  'Other Income',
}

local function ensure_mini_pick()
  local ok, MiniPick = pcall(require, 'mini.pick')
  if not ok then
    pcall(vim.cmd.packadd, 'mini.nvim')
    ok, MiniPick = pcall(require, 'mini.pick')
  end
  return ok and MiniPick or nil
end

local function prompt_transaction(opts)
  local MiniPick = ensure_mini_pick()
  if not MiniPick then
    vim.notify('mini.pick is not loaded', vim.log.levels.WARN)
    return
  end

  MiniPick.start {
    source = {
      name = opts.picker_title,
      items = opts.categories,
      choose = function(selected_cat)
        if not selected_cat then return end
        vim.ui.input({ prompt = opts.amount_prompt }, function(amount_str)
          if not amount_str or amount_str == '' then return end
          local amount = tonumber(amount_str)
          if not amount then
            vim.notify('Invalid amount: ' .. amount_str, vim.log.levels.ERROR)
            return
          end

          vim.ui.input({ prompt = 'Description: ' }, function(desc)
            if not desc or desc == '' then return end
            run_cmd({ 'uv', 'run', 'finance', opts.subcommand, tostring(amount), desc, '-c', selected_cat }, function(stdout)
              vim.notify(stdout ~= '' and stdout or ('Logged ' .. opts.sign .. amount .. ' for ' .. desc), vim.log.levels.INFO, { title = opts.notify_title })
            end)
          end)
        end)
      end,
    },
  }
end

function M.add_expense_picker()
  prompt_transaction {
    picker_title = '💸 Select Expense Category',
    categories = EXPENSE_CATEGORIES,
    amount_prompt = 'Expense Amount: ',
    subcommand = 'add-expense',
    sign = '-',
    notify_title = 'Expense Logged',
  }
end

function M.add_income_picker()
  prompt_transaction {
    picker_title = '💰 Select Income Category',
    categories = INCOME_CATEGORIES,
    amount_prompt = 'Income Amount: ',
    subcommand = 'add-income',
    sign = '+',
    notify_title = 'Income Logged',
  }
end

function M.recurring_picker()
  local MiniPick = ensure_mini_pick()
  if not MiniPick then return end

  local proj_dir = get_proj_dir()
  local py_code = "from spreadsheet import Config; import json; cfg = Config.load(); print(json.dumps([{'name': r['name'], 'amount': r['amount'], 'category': r.get('category',''), 'account': r.get('account','')} for r in cfg.recurring_payments]))"

  local res = vim.system({ 'uv', 'run', 'python', '-c', py_code }, { cwd = proj_dir }):wait()
  local bills = {}
  if res.code == 0 and res.stdout and res.stdout ~= '' then pcall(function() bills = vim.json.decode(res.stdout) end) end

  if #bills == 0 then
    bills = {
      { name = 'Phone & Mobile Plan', amount = 50.0, category = 'Utilities: Internet & Mobile', account = 'Credit Card' },
      { name = 'Home Fiber Internet', amount = 90.0, category = 'Utilities: Internet & Mobile', account = 'Credit Card' },
      { name = 'Apartment Rent', amount = 1200.0, category = 'Housing: Rent / Mortgage', account = 'Checking Account' },
      { name = 'Streaming Subscriptions', amount = 35.0, category = 'Subscriptions: Streaming & Apps', account = 'Credit Card' },
    }
  end

  local items = {}
  local bill_map = {}
  for _, b in ipairs(bills) do
    local label = string.format('%s  |  %0.2f  |  %s', b.name, b.amount, b.category)
    table.insert(items, label)
    bill_map[label] = b
  end

  MiniPick.start {
    source = {
      name = '🔁 Log Recurring Bill (1-Click)',
      items = items,
      choose = function(chosen)
        local bill = chosen and bill_map[chosen]
        if not bill then return end
        run_cmd({
          'uv',
          'run',
          'finance',
          'add-expense',
          tostring(bill.amount),
          bill.name,
          '-c',
          bill.category,
          '-a',
          bill.account,
          '-t',
          'recurring',
        }, function(stdout) vim.notify('Logged recurring bill:\n' .. stdout, vim.log.levels.INFO, { title = 'Recurring Logged' }) end)
      end,
    },
  }
end

function M.run_all_recurring()
  run_cmd({ 'uv', 'run', 'finance', 'recurring' }, function(stdout) vim.notify(stdout, vim.log.levels.INFO, { title = 'Recurring Monthly Sync' }) end)
end

function M.show_summary()
  local proj_dir = get_proj_dir()
  if Snacks and Snacks.terminal then
    Snacks.terminal.open('uv run finance summary', { cwd = proj_dir })
    return
  end

  run_cmd({ 'uv', 'run', 'python', 'scripts/monthly_report.py' }, function(stdout)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(stdout, '\n'))
    local width = math.min(65, vim.o.columns - 4)
    local height = math.min(18, vim.o.lines - 4)
    vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      border = 'rounded',
      title = ' 📊 Monthly Financial Summary ',
      title_pos = 'center',
    })
  end)
end

function M.browse_wishlist()
  local MiniPick = ensure_mini_pick()
  if not MiniPick then return end

  local proj_dir = get_proj_dir()
  local py_code = 'from spreadsheet import Tracker; import json; t = Tracker(); print(json.dumps(t.list_wishlist()))'
  local res = vim.system({ 'uv', 'run', 'python', '-c', py_code }, { cwd = proj_dir }):wait()
  local items_data = {}
  if res.code == 0 and res.stdout and res.stdout ~= '' then pcall(function() items_data = vim.json.decode(res.stdout) end) end

  local display_items = {}
  for _, item in ipairs(items_data) do
    table.insert(display_items, string.format('%s  |  %s  |  Cost: %s  |  Status: %s', item.priority, item.item_name, item.cost, item.status))
  end

  if #display_items == 0 then table.insert(display_items, 'No wishlist items found.') end

  MiniPick.start {
    source = {
      name = '🎁 Wishlist Acquisitions',
      items = display_items,
      choose = function(chosen)
        if chosen then vim.notify(chosen, vim.log.levels.INFO, { title = 'Wishlist Item' }) end
      end,
    },
  }
end

function M.open_in_browser()
  local proj_dir = get_proj_dir()
  local py_code = 'from spreadsheet.client import open_or_create_spreadsheet; sh, _ = open_or_create_spreadsheet(); print(sh.url)'
  local res = vim.system({ 'uv', 'run', 'python', '-c', py_code }, { cwd = proj_dir }):wait()
  if res.code == 0 and res.stdout and res.stdout ~= '' then
    local url = vim.trim(res.stdout)
    pcall(vim.ui.open, url)
    vim.notify('Opened spreadsheet in browser: ' .. url, vim.log.levels.INFO)
  else
    vim.notify('Could not retrieve spreadsheet URL', vim.log.levels.WARN)
  end
end

function M.edit_config()
  local cfg_path = get_proj_dir() .. '/user_config.py'
  vim.cmd('edit ' .. vim.fn.fnameescape(cfg_path))
end

local master_actions = {
  { label = '💳 Log Expense', fn = M.add_expense_picker },
  { label = '💰 Log Income', fn = M.add_income_picker },
  { label = '🔁 Log Single Recurring Bill (1-Click)', fn = M.recurring_picker },
  { label = '🚀 Run All Recurring Bills for Current Month', fn = M.run_all_recurring },
  { label = '📊 Monthly Financial Summary', fn = M.show_summary },
  { label = '🎁 Browse Wishlist', fn = M.browse_wishlist },
  { label = '🌐 Open Spreadsheet in Browser', fn = M.open_in_browser },
  { label = '⚙️ Edit user_config.py', fn = M.edit_config },
}

function M.actions()
  local MiniPick = ensure_mini_pick()
  if not MiniPick then
    vim.notify('mini.pick is not loaded', vim.log.levels.WARN)
    return
  end

  local labels = {}
  local by_label = {}
  for _, act in ipairs(master_actions) do
    table.insert(labels, act.label)
    by_label[act.label] = act.fn
  end

  MiniPick.start {
    source = {
      name = '📑 Google Sheets Financial Operations',
      items = labels,
      choose = function(item)
        local fn = item and by_label[item]
        if fn then fn() end
      end,
    },
  }
end

function M.setup()
  if initialized then return end
  initialized = true

  local MiniPick = ensure_mini_pick()
  if MiniPick and MiniPick.registry then
    MiniPick.registry.gspread_actions = M.actions
    MiniPick.registry.gspread_expense = M.add_expense_picker
    MiniPick.registry.gspread_income = M.add_income_picker
    MiniPick.registry.gspread_recurring = M.recurring_picker
    MiniPick.registry.gspread_summary = M.show_summary
    MiniPick.registry.gspread_wishlist = M.browse_wishlist
  end

  vim.api.nvim_create_user_command('GSpread', M.actions, { desc = 'Master Google Sheets picker' })
  vim.api.nvim_create_user_command('Expense', function(opts)
    if opts.args ~= '' then
      run_cmd(vim.list_extend({ 'uv', 'run', 'finance', 'add-expense' }, vim.split(opts.args, '%s+')))
    else
      M.add_expense_picker()
    end
  end, { nargs = '*', desc = 'Log expense transaction' })

  vim.api.nvim_create_user_command('Income', function(opts)
    if opts.args ~= '' then
      run_cmd(vim.list_extend({ 'uv', 'run', 'finance', 'add-income' }, vim.split(opts.args, '%s+')))
    else
      M.add_income_picker()
    end
  end, { nargs = '*', desc = 'Log income transaction' })

  vim.api.nvim_create_user_command('Recurring', function(opts)
    if opts.args ~= '' then
      run_cmd { 'uv', 'run', 'finance', 'recurring', opts.args }
    else
      M.run_all_recurring()
    end
  end, { nargs = '?', desc = 'Run recurring monthly bills' })

  vim.api.nvim_create_user_command('FinanceSummary', function(opts)
    if opts.args ~= '' then
      run_cmd { 'uv', 'run', 'finance', 'summary', '-m', opts.args }
    else
      M.show_summary()
    end
  end, { nargs = '?', desc = 'Show financial summary' })

  local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { silent = true, desc = desc }) end

  map('<leader>GG', M.actions, 'GSpread: Master Operations')
  map('<leader>Ga', M.actions, 'GSpread: Operations Picker')
  map('<leader>Ge', M.add_expense_picker, 'GSpread: Log Expense')
  map('<leader>Gi', M.add_income_picker, 'GSpread: Log Income')
  map('<leader>Gr', M.recurring_picker, 'GSpread: Log Recurring Bill')
  map('<leader>Gs', M.show_summary, 'GSpread: Monthly Summary')
  map('<leader>Gw', M.browse_wishlist, 'GSpread: Wishlist')
  map('<leader>Go', M.open_in_browser, 'GSpread: Open Sheet in Browser')
  map('<leader>Gc', M.edit_config, 'GSpread: Edit user_config.py')
end

return M
