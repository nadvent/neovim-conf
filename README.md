# Neovim

## Introduction

My neovim setup documentation that I use with Umbriel + Noctalia. I used distros before for around 2-3 years when I was studying. Now, I'm transitioning to writing my own config using [Kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) as a base config. See my [dotfiles](https://github.com/nadvent/dotfiles) for my other config files.

![Neovim Workspace — Statusline & Autocompletion](assets/preview.png)

---

## Installation

1. Install [Neovim](https://neovim.io/doc/install/)
2. Some linux dependencies

```bash
sudo pacman -S --needed git base-devel gcc cmake make ripgrep fd fzf sed unzip tar curl wget tree-sitter tree-sitter-cli nodejs npm python python-pip go rustup yazi lazygit wl-clipboard
```

3. Patched [nerd font](https://www.nerdfonts.com/)
4. Run `:checkhealth` to see if there's anything missing.

---

## Core

1. **Native Package Management (`vim.pack`)**: All plugins are declared and managed directly through Neovim's native package manager (`vim.pack.add`).
2. **Fast Startup**: Optimized with `vim.loader.enable()`, deferred DAP/Mason initialization, buffer-lazy UI editing plugins, `ColorSchemePre` theme loading, and on-demand filetype/project toolchains.
3. **Semantic Keymap Topology**: Most keybindings follow `<leader>` namespaces (`<leader>c` for Code, `<leader>d` for Debug, `<leader>r` for Runner, `<leader>g` for Git, `<leader>u` for UI toggles, etc).

---

## Directory Structure

```text
~/.config/nvim/
├── init.lua                        # Bootstrap with vim.loader, module order & FileType router
└── lua/
    ├── icons.lua                   # Centralized UI/diag/git glyphs & real-icons/mini.icons resolver
    │
    ├── core/                       # Shared utilities & editor fundamentals
    │   ├── util.lua                # Path predicates, GitHub helper, color math & keymap/augroup utils
    │   ├── options.lua             # Vanilla Vim options & sensible defaults
    │   ├── themes.lua              # Colorscheme selection (koda-light) & lazy theme registration
    │   ├── noctalia.lua            # Ghostty M3 palette / standard UI & picker highlight profiles
    │   ├── autocmd.lua             # Core autocommands (yank, autoread, cursor, project toolchains)
    │   ├── diagnostics.lua         # Fancy diagnostic hover floats & severity bar statuscolumn
    │   └── keymaps.lua             # Global keymap topology & which-key group descriptors
    │
    ├── plugins/                    # Central plugin engines
    │   ├── init.lua                # PackChanged build hooks (registered before vim.pack.add)
    │   ├── ux.lua                  # Snacks, navigation, text-objects, mini.indentscope, icons, dropbar, bento, which-key
    │   ├── pick.lua                # Mini.pick + Mini.extra & custom project/TODO/GitHub pickers
    │   ├── mini_surround_wk.lua    # Which-key prefix label helper for mini.surround
    │   ├── code.lua                # Unified LSP, Blink.cmp, Conform, Lint, DAP, Overseer, Sidekick
    │   ├── git.lua                 # Gitsigns hunk actions, LazyGit & Diffmantic integration
    │   └── statusline.lua          # Native statusline using winid-aware mode, LSP, git & task indicators
    │
    ├── tasks/                      # JIRA-style task/bug tracker, time footprints & Kitty TUI integration
    │   ├── init.lua                # Commands (:TaskBoard, :TaskBug, :TaskUI, etc.) & MiniPick hooks
    │   ├── client.lua              # Async `tsk` CLI bridge & O(1) statusline state cache
    │   ├── tracker.lua             # Idle-aware heartbeat timer & git branch auto-association
    │   ├── capture.lua             # Quick capture, cursor bug capture & TODO comment promotion
    │   ├── pickers.lua             # Mini.pick task/bug search, timer switcher & gh sync
    │   ├── board.lua               # Floating Kanban/category board with Oklab highlight pills
    │   ├── detail.lua              # Centralized per-ticket Markdown doc viewer, SQLite sync & git diff viewer
    │   └── report.lua              # Time/git footprint analytics & tmux/Kitty `tsk ui` launcher
    │
    ├── plugins/opt/                # Language & project toolchains (loaded on FileType or directory)
    │       ├── cpp.lua             # C/C++ clangd extensions & inspection bindings
    │       ├── python.lua          # Quarto, Otter, venv-selector & debugpy
    │       ├── rust.lua            # Rustaceanvim, Crates.nvim & Cargo workflows
    │       ├── java.lua            # nvim-jdtls refactoring & JUnit test runners
    │       ├── typst.lua           # Typst-preview live sync & math-conceal rendering
    │       ├── latex.lua           # VimTeX live compilation & PDF viewer sync
    │       ├── markdown.lua        # Render-markdown in-buffer preview & Vellum preview
    │       ├── php.lua             # Laravel Artisan/routes picker
    │       ├── gspread.lua         # Google Sheets finance pickers (loaded in spreadsheet dir)
    │       └── leetcode.lua        # leetcode.nvim workflows (loaded in LeetCode dir)
    │
    └── overseer/
        └── template/
            └── user/
                ├── cmake_build_run.lua # Dynamic CMake target generator & interactive builder
                ├── cpp_build_run.lua   # Standalone single-file compiler & runner
                └── uv_python.lua       # Python uv script/sync/pytest/lock templates
```

---

## Coding Features (`lua/plugins/code.lua`)

All core coding subsystems are orchestrated in `lua/plugins/code.lua`:

- **LSP (`nvim-lspconfig` + `mason.nvim`)**: Server definitions are registered via `vim.lsp.config`, while Mason setup and automatic tool installation are deferred until `vim.schedule()` or explicit `:Mason*` invocation.
- **Completion (`blink.cmp`)**: Rust-fuzzy completion engine configured with LuaSnip preset, ghost text, signature help, and source isolation for Overseer forms.
- **Formatting (`conform.nvim`)**: Asynchronous formatting on save (`format_on_save`), falling back to LSP when CLI tools are absent.
- **Linting (`nvim-lint`)**: Background static analysis on buffer enter, write, and insert leave.
- **Debugging (`nvim-dap` + `nvim-dap-view`)**: On-demand DAP initialization (`require('plugins.code').load_dap()`) with Mason adapter management.
- **Task Runner (`overseer.nvim`)**: Task runner with terminal output, quickfix integration, and custom C/C++/CMake/`uv` templates.
- **Syntax (`nvim-treesitter`)**: Main-branch tree-sitter parser installation, automatic `vim.treesitter.foldexpr()` folding (`<leader>uF` / hybrid `zf`), and `.select` / `.move` textobjects (`am`/`im`, `ac`/`ic`, `ak`/`ik`, `]m`/`[m`).
- **AI Assistant (`sidekick.nvim`)**: Integrated CLI (`Antigravity` default toggle on `<leader>ac`), prompt templates, and Copilot Next Edit Suggestions (NES).

---

## Language Ecosystems & Workflows

### 1. C & C++

- **Language Server**: `clangd` with detailed completions, background indexing, and automatic header insertion (`iwyu`).
- **AST & Hierarchy**: `clangd_extensions.nvim` provides type hierarchy trees (`<leader>ct`), memory usage footprints (`<leader>cm`), AST dumps (`<leader>cA`), symbol info (`<leader>cS`), and header/source swapping (`<leader>ch`).
- **Build & Run (Overseer)**:
  - Running `<leader>rr` inspects `CMakeLists.txt`, detects `add_executable(...)` targets, and lists direct build-and-run tasks.
  - Choosing `CMake: Custom Build & Run (Configure...)` interactively prompts for target, compiler (`clang` vs `gcc`), build type (`Debug + ASan`, `Release`), and optional defines.
  - Compiling standalone files with `Single File: Compile & Run` allows instant builds with custom optimization and sanitizer flags.

### 2. Python

- **LSP & Typing**: `basedpyright` for type checking paired with `astral-sh/ruff` for linting, formatting, and import sorting (`uv` / `pyproject` project settings + standalone LeetCode profile).
- **Notebooks & Quarto**: `quarto-nvim` + `otter.nvim` provide embedded code block completion and interactive notebook execution (`<leader>rp` to preview, `<leader>rc` to run current cell, `<leader>rA` to run all cells).
- **Virtual Environments**: `venv-selector.nvim` discovers and switches poetry, venv, and conda environments dynamically (`<leader>cv` or `,v`).
- **Testing & DAP**: `nvim-dap-python` binds single-test debugging (`<leader>dpm` for test method, `<leader>dpc` for test class).

### 3. Typst

- **LSP & Formatter**: `tinymist` provides LSP diagnostics, PDF export on type, and formatting via `typstyle`.
- **Live Sync & Math**: `chomosuke/typst-preview.nvim` runs a preview server with cursor following (`<leader>uv`, `<leader>uf`), paired with `math-conceal.nvim`.

### 4. LaTeX

- **Compilation**: `lervag/vimtex` provides continuous background builds with `latexmk` (`<leader>ll`), error navigation, and Table of Contents inspection (`<leader>lt`).
- **Viewer Integration**: Forward and inverse SyncTeX search wired to Zathura (`<leader>lv`).
- **High-Speed Formatting**: `tex-fmt` (Rust-based) formats `.tex`/`.bib` documents without the overhead of Perl's `latexindent`.

### 5. Markdown

- **In-Buffer & Preview**: `render-markdown.nvim` renders tables and LaTeX inline (`<leader>um`), while `vellum.nvim` handles diagram/Markdown preview (`<leader>mp`), zoom (`<leader>mz`), and PDF export (`<leader>me`).

---

## Keymap Cheat Sheet

Please refer to [lua/core/keymaps.lua](lua/core/keymaps.lua) and `lua/plugins/opt/*.lua` for the complete list of bindings.

<details>
<summary><strong>Expand Which-Key Groups & Core Keymaps</strong></summary>

### Which-Key Groups Cheat Sheet

| Which-Key Group                     | Description                                                         | Keymaps & Examples                                                                                                                                                                                                                                                                                                                |
| :---------------------------------- | :------------------------------------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`<leader>a`**<br>`AI Assistant`   | Sidekick AI CLI integration, prompt templates, and session controls | • `<C-.>` Focus assistant terminal<br>• `<leader>aa` Toggle Sidekick CLI<br>• `<leader>ac` Toggle Antigravity CLI<br>• `<leader>at` Send `{this}` context<br>• `<leader>av` Send visual selection<br>• `<leader>ap` Select prompt template                                                                                       |
| **`<leader>b`**<br>`Buffers`        | Buffer switching, listing, and layout-preserving deletion           | • `<leader>bb` / `<leader>,` List and switch buffers via Mini.pick<br>• `<leader>`\` Switch to alternate (last active) buffer<br>• `<leader>bd` Delete buffer safely without breaking splits (`mini.bufremove`)<br>• `<leader>bD` Force delete buffer                                                                             |
| **`<leader>c`**<br>`Code / LSP`     | Formatting, diagnostics, symbol pickers, and LSP actions            | • `<leader>cf` Format buffer (Conform with LSP fallback)<br>• `<leader>cd` Show line diagnostics in fancy floating window<br>• `<leader>cs` Document symbols picker (Mini.extra)<br>• `<leader>cl` LSP references picker (Mini.extra)<br>• `<leader>ci` / `<leader>co` Incoming / outgoing call hierarchy                         |
| **`<leader>d`**<br>`Debug`          | nvim-dap debugger execution, breakpoints, and UI toggle             | • `<leader>dc` / `<F5>` Start or continue debugging<br>• `<leader>db` / `<leader>dB` Toggle breakpoint / conditional breakpoint<br>• `<leader>di` / `<F1>` Step into; `<leader>do` / `<F2>` Step over; `<leader>dO` / `<F3>` Step out<br>• `<leader>du` / `<F7>` Toggle debug UI (`nvim-dap-view`)                            |
| **`<leader>f`**<br>`Files / Find`   | File creation, file browser, and Yazi integration                   | • `<leader>e` Toggle `mini.files` explorer<br>• `<leader>ff` Open Yazi at current file<br>• `<leader>fF` Open Yazi at CWD<br>• `<leader>fp` Find projects<br>• `<leader>fn` Create new empty buffer                                                                                                                               |
| **`<leader>G`**<br>`Google Sheets`  | Finance & wishlist spreadsheet workflows (inside spreadsheet dir)   | • `<leader>GG` / `<leader>Ga` Operations picker<br>• `<leader>Ge` / `<leader>Gi` / `<leader>Gr` Log expense, income, or recurring bill<br>• `<leader>Gs` Monthly summary<br>• `<leader>Gw` Wishlist<br>• `<leader>Go` Open sheet in browser                                                                                      |
| **`<leader>g`**<br>`Git`            | LazyGit terminal, commit history, Diffmantic, and GitHub pickers    | • `<leader>gg` Open LazyGit floating terminal<br>• `<leader>gs` Modified files picker (Mini.extra)<br>• `<leader>gl` / `<leader>gL` Git commit log / active buffer commits<br>• `<leader>gb` List and checkout branches<br>• `<leader>gd` / `<leader>gD` Diffmantic diff/clear<br>• `<leader>gi` / `<leader>gp` GitHub issues / PRs |
| **`<leader>h`**<br>`Git Hunks`      | Gitsigns hunk staging, resetting, inline previews, and diffing      | • `<leader>hs` / `<leader>hr` Stage / reset hunk (or visual selection)<br>• `<leader>hp` / `<leader>hi` Preview hunk (floating popup / inline)<br>• `<leader>hb` Show full git blame for current line<br>• `<leader>hd` / `<leader>hD` Diff against index / last commit<br>• `ih` Text object to operate inside git hunk        |
| **`<leader>l`**<br>`Lang / LeetCode`| Toolchain-specific bindings (LaTeX, PHP, LeetCode)                  | • LaTeX: `<leader>ll` compile, `<leader>lv` view PDF, `<leader>lt` TOC<br>• PHP/Laravel: `<leader>la` artisan, `<leader>lr` routes<br>• LeetCode (in LeetCode dir): `<leader>lp` list, `<leader>lr` run tests, `<leader>ls` submit                                                                                               |
| **`<leader>m`**<br>`Markdown`       | Markdown/Quarto Vellum preview and export                           | • `<leader>mp` Toggle Vellum preview<br>• `<leader>mz` Zoom diagram / image<br>• `<leader>me` Export Markdown to PDF                                                                                                                                                                                                              |
| **`<leader>p`**<br>`Projects`       | Project picker, scratchpads, and Snacks terminal                    | • `<leader>pp` Find projects (Mini.pick)<br>• `<leader>pt` / `<C-/>` Toggle project terminal<br>• `<leader>pn` Toggle project scratchpad<br>• `<leader>ps` Restore project session (`mini.sessions`)                                                                                                |
| **`<leader>q`**<br>`Session / Quit` | `mini.sessions` restoration, saving controls, and quitting          | • `<leader>qs` Restore session for current working directory<br>• `<leader>ql` Restore last active session<br>• `<leader>qS` Select from saved sessions<br>• `<leader>qw` Save session<br>• `<leader>qq` Quit all windows and exit (`:qa`)                                                                                        |
| **`<leader>r`**<br>`Run / Overseer` | Task runner execution, task actions, and fast re-runs               | • `<leader>rr` Run task from templates (`:OverseerRun`)<br>• `<leader>rt` Toggle task runner status panel<br>• `<leader>ra` Task action (`:OverseerTaskAction`)<br>• `<leader>rR` Rerun most recent successful task                                                                                                               |
| **`<leader>s`**<br>`Search`         | Mini.pick / Mini.extra fuzzy finding across files, grep, and lists  | • `<leader><Space>` / `<leader>sf` Find files in workspace<br>• `<leader>sg` Live grep across project files<br>• `<leader>sw` Grep word under cursor<br>• `<leader>/` Fuzzy search within current buffer<br>• `<leader>st` / `<leader>sb` Search TODOs / bugs<br>• `<leader>sn` Search Neovim config<br>• `<leader>sr` Resume search |
| **`<leader>t`**<br>`Tasks / Time`   | Local-first JIRA-style tasks, bugs, git links & time footprints     | • `<leader>tb` Open Kanban task & bug board<br>• `<leader>tB` Capture bug at cursor (diagnostics/TS/blame)<br>• `<leader>tc` Quick capture task/feature/epic<br>• `<leader>tl` / `<leader>tL` Search project / global tasks<br>• `<leader>tt` / `<leader>tp` Switch / pause timer<br>• `<leader>to` Active ticket detail & diffs<br>• `<leader>tg` Git branch/hooks menu<br>• `<leader>tr` Footprint report; `<leader>tu` Visual Kitty TUI<br>• `<leader>ts` GitHub sync; `<leader>tx` Promote TODO |
| **`<leader>u`**<br>`UI / Settings`  | Editor display toggles, theme profiles, syntax inspection, pack UI  | • `<leader>uw` Line wrap; `<leader>us` Spell; `<leader>ul` Relative numbers<br>• `<leader>ud` Diagnostics; `<leader>uc` Conceal level; `<leader>uh` Inlay hints<br>• `<leader>ub` Git blame; `<leader>uW` Git word diff<br>• `<leader>uv` / `<leader>uf` Typst preview / follow cursor<br>• `<leader>uz` Zen mode; `<leader>uF` Fold method; `<leader>up` Theme profile; `<leader>uP` Pack UI |
| **`<leader>w`**<br>`Windows`        | Split creation, resizing, and window balancing                      | • `<leader>-` Split window horizontally (below)<br>• `<leader>\|` Split window vertically (right)<br>• `<leader>wd` Close active window split<br>• `<leader>w=` Balance window sizes equally                                                                                                                                      |
| **`<leader>x`**<br>`Diagnostics`    | Project/buffer diagnostics, TODOs, quickfix, and location pickers   | • `<leader>xx` / `<leader>xX` Workspace / buffer diagnostics (Mini.extra)<br>• `<leader>xt` / `<leader>xT` Project / buffer TODOs (Mini.pick)<br>• `<leader>xq` / `<leader>xl` Toggle quickfix / location list<br>• `<leader>xD` Send buffer diagnostics to location list                                                         |
| **`<leader><Tab>`**<br>`Tabs`       | Tab creation, navigation, and tab closing                           | • `<leader><Tab><Tab>` Open new tab<br>• `<leader><Tab>d` Close active tab<br>• `<leader><Tab>o` Close other tabs<br>• `<leader><Tab>]` / `[` Go to next / previous tab                                                                                                                                                           |
| **`g`**<br>`Goto`                   | Code definitions, peeks, symbols, diagnostics, and comments         | • `gd` Goto definition via Mini.extra<br>• `gD` / `gT` Peek definition / type definition via `lspeek`<br>• `gl` Line diagnostics float<br>• `gO` / `gW` Document / workspace symbols picker<br>• `gco` / `gcO` Add comment line below / above                                                                                       |
| **`gr`**<br>`LSP Actions`           | Language server cross-references, renames, and implementations      | • `grr` Goto references via Mini.extra<br>• `gri` Goto interface implementations<br>• `grt` Goto type definitions<br>• `grD` Goto declaration<br>• `grn` Rename; `gra` Code action                                                                                                                                                |

## Core Non-Leader Keymaps

| Category                  | Keymaps                                                                                                               | Description / Example                                                                                                                                                                                                                                                                                                                                                                                         |
| :------------------------ | :-------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Navigation & Jumps**    | `s` / `S`<br>`r` / `R`<br>`]c` / `[c`<br>`]d` / `[d`<br>`[b` / `]b` (or `<S-h>` / `<S-l>`)                            | • `s` / `S`: Flash 2-char jump / treesitter node jump<br>• `r` / `R`: Remote Flash / treesitter search in operator mode<br>• `]c` / `[c`: Jump to next / previous git change<br>• `]d` / `[d`: Jump to next / previous diagnostic (`]e` error, `]w` warning)<br>• `[b` / `]b`: Previous / next open buffer                                                                                                    |
| **Window Focus & Sizing** | `<C-h>` `<C-j>` `<C-k>` `<C-l>`<br>`<C-Up>` `<C-Down>` `<C-Left>` `<C-Right>`                                         | • `<C-h/j/k/l>`: Navigate directly to left/down/up/right split<br>• `<C-Arrows>`: Resize active split height/width by ±2 lines/columns                                                                                                                                                                                                                                                                        |
| **Editing & Ergonomics**  | `<C-s>`<br>`<A-j>` / `<A-k>`<br>`p` (visual)<br>`<` / `>` (visual)<br>`,` `.` `;` (insert)<br>Double-`<Esc>` / `<C-q>` (terminal) | • `<C-s>`: Save file from insert, normal, or visual mode<br>• `<A-j>` / `<A-k>`: Bubble current line or visual selection up / down<br>• `p`: Paste visual selection without replacing clipboard contents<br>• `<` / `>`: Indent selection left/right and retain visual highlight<br>• `,` `.` `;`: Create automatic undo breakpoints while typing<br>• Double-`<Esc>` (Snacks terminal) / `<C-q>` (Sidekick): Exit terminal insert mode |

</details>

---

## Custom Integrations & Technical Highlights

### 1. Native `blink.cmp` Provider for Overseer Forms

Overseer opens a floating input buffer when configuring tasks with parameters, setting `vim.bo.omnifunc = "v:lua.overseer_form_omnifunc"`. A native Blink source (`blink-overseer`) registered directly in `lua/plugins/code.lua`:

- Dynamically executes Overseer's omnifunc to fetch enum values (`clang`, `gcc`, `Debug`, `Release`).
- Prioritizes Overseer choices for autocompletion.
- Uses dynamic source evaluation (`sources.default = function()`) to mute LSP and snippets inside the form, presenting an isolated completion list.

### 2. Dynamic CMake Target Generator

The Overseer template in `lua/overseer/template/user/cmake_build_run.lua` is written as an `overseer.TemplateFileProvider`:

- Reads `CMakeLists.txt` via Lua pattern matching to extract active executable targets.
- Dynamically injects dedicated build-and-run tasks for each detected target into the `:OverseerRun` menu.
- Configures, builds, and executes `./build-<type>-<compiler>/<target>` directly with safely shell-escaped arguments.

### 3. Noctalia Dynamic Theme Profile

Defaults to `koda-light` (`standard` profile in `lua/core/themes.lua`), with a toggleable profile (`<leader>up`) managed by `lua/core/noctalia.lua` to switch between Standard highlights and Noctalia's M3 Material palette read from Ghostty (`~/.config/ghostty/themes/noctalia`):

- Uses [Dayfox](https://github.com/edeneast/nightfox.nvim) as the base colorscheme for the Noctalia profile while registering optional themes lazily via `ColorSchemePre`.
- Applies consistent transparency rules to Winbar, Dropbar, Tabline, and Bento (`DropBar*`, `TabLine*`, `BentoNormal`).
- Unifies statusline mode colors and picker chrome (`MiniPick*`, `SnacksPicker*`) across both profiles, emitting `User NoctaliaReload` on switches.
