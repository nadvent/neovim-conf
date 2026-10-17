# kickstart.nvim

## Introduction

My (WIP) neovim setup documentation that I use with Niri + Noctalia. I used distros before (e.g. [LunarVim](https://github.com/lunarvim/lunarvim) and [LazyVim](https://www.lazyvim.org/)) before for my studies in college - where I didn't even have a laptop, just used Termux - and university. After awhile, there's a lot of features that are built into neovim itself, I changed to [Zed](https://zed.dev/). It's pretty good, but I have some time to kill, so I thought why not write my neovim config from scratch this time for self-learning.

---

## Core

1. **Native Package Management (`vim.pack`)**: All plugins are declared and managed directly through Neovim 0.12's native package manager (`vim.pack.add`).
2. **~100ms Startup**: Optimized with `vim.loader.enable()`, deferred DAP/Mason initialization, on-demand UI loaders, and lazy filetype modules.
3. **Semantic Keymap Topology**: Most keybinding follows `<leader>` namespaces (`<leader>c` for Code, `<leader>d` for Debug, `<leader>r` for Runner, `<leader>g` for Git, `<leader>u` for UI toggles, etc).

---

## Directory Structure

```text
~/.config/nvim/
├── init.lua                        # Fast bootstrap with bytecode caching (vim.loader)
├── icons.lua                       # Centralized glyph and symbol mappings
│
├── core/                           # Editor fundamentals
│   ├── options.lua                 # Vanilla Vim options & sensible defaults
│   ├── keymaps.lua                 # Global keymap topology & which-key groups
│   ├── autocmd.lua                 # General autocommands (highlight on yank, etc.)
│   ├── themes.lua                  # Colorscheme selection (Dayfox / Nightfox)
│   └── ui_highlights.lua           # Custom highlight overrides
│
├── plugins/                        # Central plugin engines
│   ├── init.lua                    # Plugin loading hub & dynamic opt/ filetype router
│   ├── code.lua                    # Unified LSP, Blink.cmp, Conform, Lint, DAP, Overseer
│   ├── ux.lua                      # Core navigation, text-objects, notifications, and icons
│   ├── git.lua                     # Gitsigns hunk actions & LazyGit integration
│   ├── statusline.lua              # Native lightweight statusline with float guards
│   ├── telescope.lua               # Fuzzy finding pickers & extensions
│   │
│   └── opt/                        # Language-specific toolchains (loaded on FileType)
│       ├── cpp.lua                 # C/C++ clangd extensions & inspection bindings
│       ├── python.lua              # Quarto, Otter, venv-selector & debugpy
│       ├── rust.lua                # Rustaceanvim, Crates.nvim & Cargo workflows
│       ├── java.lua                # nvim-jdtls refactoring & JUnit test runners
│       ├── typst.lua               # Typst-preview live sync & Tinymist hooks
│       ├── latex.lua               # VimTeX live compilation & PDF viewer sync
│       ├── markdown.lua            # Render-markdown in-buffer preview & browser preview
│       └── php.lua                 # Laravel Artisan/routes picker & Pint/PHPStan
│
└── overseer/
    └── template/
        └── user/
            ├── cmake_build_run.lua # Dynamic CMake target generator & interactive builder
            └── cpp_build_run.lua   # Standalone single-file compiler & runner
```

---

## Coding Features (`plugins/code.lua`)

All core coding subsystems are orchestrated in `plugins/code.lua`:

- **LSP (`nvim-lspconfig` + `mason.nvim`)**: Pre-configured servers and server definitions are registered immediately to be attached, while package management runs asynchronously via `vim.schedule()`.
- **Completion (`blink.cmp`)**: Rust-fuzzy completion engine configured with LuaSnip preset, ghost text, signature help, and source isolation for Overseer.
- **Formatting (`conform.nvim`)**: Asynchronous formatting on save with `format_on_save`, fallback to LSP when CLI tools are absent.
- **Linting (`nvim-lint`)**: Background static analysis on buffer write and text changes.
- **Debugging (`nvim-dap` + `nvim-dap-view`)**: Complete DAP suite with automatic adapter installation.
- **Task Runner (`overseer.nvim`)**: VS Code-compatible task runner integrated with terminal runners, quickfix error matching, and custom C/C++ templates.
- **Syntax (`nvim-treesitter`)**: Main-branch tree-sitter installation with custom incremental textobjects and automatic parser attachment per buffer.
- **AI Assistant (`sidekick.nvim`)**: Integrated CLI with Gemini-CLI and Copilot Next Edit Suggestions (NES) and prompt assistant hooked into terminal workflows and keymaps.

---

## Language Ecosystems & Workflows

### 1. C & C++

- **Language Server**: `clangd` with detailed completions, background indexing, and automatic header insertion (`iwyu`).
- **AST & Hierarchy**: `clangd_extensions.nvim` provides type hierarchy trees (`<leader>ct`), memory usage footprints (`<leader>cm`), AST dumps (`<leader>cA`), and header/source swapping (`<leader>ch`).
- **Build & Run (Overseer)**:
  - Running `<leader>rr` automatically inspects `CMakeLists.txt`, auto-detects all `add_executable(...)` targets, and lists direct build-and-run tasks.
  - Choosing `CMake: Custom Build & Run (Configure...)` interactively prompts for target, compiler (`clang` vs `gcc`), build type (`Debug + ASan`, `Release`), and optional defines.
  - Compiling standalone files with `Single File: Compile & Run` allows instant builds with custom optimization and sanitizer flags.

### 2. Python

- **LSP & Typing**: `basedpyright` for strict type checking paired with `astral-sh/ruff` for sub-millisecond linting and import sorting.
- **Notebooks & Quarto**: `quarto-nvim` + `otter.nvim` provide embedded code block completion and interactive notebook execution (`<leader>qp` to preview, `<leader>rc` to run current cell).
- **Virtual Environments**: `venv-selector.nvim` discovers and switches poetry, venv, and conda environments dynamically (`<leader>cv` or `,v`).
- **Testing & DAP**: `nvim-dap-python` binds single-test debugging (`<leader>dpm` for test method, `<leader>dpc` for test class).

### 3. Typst

- **LSP & Formatter**: `tinymist` provides LSP diagnostics, automatic PDF export, and formatting via `typstyle`.
- **Live Sync**: `chomosuke/typst-preview.nvim` runs a low-latency preview server in your browser with bidirectional cursor scrolling (`<leader>tp`).

### 4. LaTeX

- **Compilation**: `lervag/vimtex` provides continuous background builds with `latexmk` (`<leader>ll`), error navigation, and Table of Contents inspection (`<leader>lt`).
- **Viewer Integration**: Forward and inverse SyncTeX search wired directly to Zathura/Sioyek (`<leader>lv`).
- **High-Speed Formatting**: `tex-fmt` (Rust-based) formats documents instantly without the overhead of Perl's `latexindent`.

---

## Keymap Cheat Sheet

### Leader Key Reference (`<Space>`)

| Prefix            | Namespace        | Common Actions                                                                                                                                                                                        |
| :---------------- | :--------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<leader>f`       | **Files**        | `<leader>fn` New file, `<leader>ff` Yazi at current file, `<leader>fF` Yazi at CWD                                                                                                                    |
| `<leader>s`       | **Search**       | `<leader><space>` Find files, `<leader>sg` Live grep, `<leader>sw` Grep word, `<leader>sd` Diagnostics, `<leader>s.` Recent files, `<leader>/` Search buffer                                          |
| `<leader>b`       | **Buffers**      | `<leader>bb` / `<leader>,` List active buffers, `<leader>\`` Switch alternate buffer, `&lt;leader&gt;bd` Safe delete (preserves window splits)                                                        |
| `&lt;leader&gt;c` | **Code / LSP**   | `&lt;leader&gt;ca` Code action, `&lt;leader&gt;cf` Format buffer, `&lt;leader&gt;cd` Line diagnostic, `&lt;leader&gt;cs` Symbols (Trouble), `&lt;leader&gt;cl` LSP definitions                        |
| `&lt;leader&gt;d` | **Debug (DAP)**  | `&lt;leader&gt;dc` Continue, `&lt;leader&gt;di` Step into, `&lt;leader&gt;do` Step over, `&lt;leader&gt;dO` Step out, `&lt;leader&gt;db` Toggle breakpoint, `&lt;leader&gt;du` Toggle Debug UI        |
| `&lt;leader&gt;r` | **Runner**       | `&lt;leader&gt;rr` Run Overseer task, `&lt;leader&gt;rt` Toggle Overseer task window, `&lt;leader&gt;ra` Task action                                                                                  |
| `&lt;leader&gt;g` | **Git**          | `&lt;leader&gt;gg` Open LazyGit, `&lt;leader&gt;gl` Git commit log, `&lt;leader&gt;gs` Git status, `&lt;leader&gt;hs` Stage hunk, `&lt;leader&gt;hr` Reset hunk, `&lt;leader&gt;tb` Toggle line blame |
| `&lt;leader&gt;u` | **UI Toggles**   | `&lt;leader&gt;uw` Line wrap, `&lt;leader&gt;us` Spell check, `&lt;leader&gt;ul` Relative numbers, `&lt;leader&gt;ud` Diagnostics, `&lt;leader&gt;uc` Conceal level                                   |
| `&lt;leader&gt;q` | **Session**      | `&lt;leader&gt;qs` Restore current directory session, `&lt;leader&gt;ql` Restore last session, `&lt;leader&gt;qq` Quit all                                                                            |
| `&lt;leader&gt;a` | **AI Assistant** | `&lt;leader&gt;aa` Toggle Sidekick CLI, `&lt;leader&gt;at` Send context, `&lt;leader&gt;af` Send file, `&lt;leader&gt;ap` Select prompt                                                               |

### Navigation & Core Shortcuts

- **Screen Line Navigation**: `j`/`k` move by visual screen lines unless a numerical count is supplied (e.g. `5j`).
- **Centered Scrolling**: `<C-d>` and `<C-u>` jump half-pages while keeping the cursor centered (`zz`).
- **Window Navigation & Resizing**: `<C-h/j/k/l>` focus adjacent windows; `<C-Up/Down/Left/Right>` resize window dimensions smoothly.
- **Safe Visual Paste**: In visual mode, `p` replaces the selection without clobbering your default clipboard register.
- **Window Splits**: `<leader>-` splits horizontally; `<leader>\|` splits vertically; `<leader>wd` closes the active window.
- **Buffer Cycles**: `<S-h>` / `<S-l>` or `[b` / `]b` cycle previous/next buffer.
- **Diagnostic Jumps**: `]d` / `[d` cycle all diagnostics; `]e` / `[e` jump directly between errors.

---

## Custom Integrations & Technical Highlights

### 1. Native `blink.cmp` Provider for Overseer Forms

Overseer opens a floating input buffer when configuring tasks with parameters, setting `vim.bo.omnifunc = "v:lua.overseer_form_omnifunc"`. Native Blink source (`blink-overseer`) directly in `plugins/code.lua`:

- Dynamically executes Overseer's omnifunc to fetch enum values (`clang`, `gcc`, `Debug`, `Release`).
- Assigns `score_offset = 100` so task options always sort at the top of the popup.
- Uses dynamic source evaluation (`sources.default = function()`) to mute LSP and snippets inside the form, presenting an isolated completion list.

### 2. Dynamic CMake Target Generator

The Overseer template in `overseer/template/user/cmake_build_run.lua` is written as an `overseer.TemplateFileProvider`:

- Reads `CMakeLists.txt` via Lua pattern matching to extract active executable targets.
- Dynamically injects dedicated build-and-run tasks for each detected target into the `:OverseerRun` menu.
- Provides a fallback runner using `find` so built binaries execute reliably regardless of build directory naming.
