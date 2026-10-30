# Neovim

## Introduction

My neovim setup documentation that I use with Umbriel + Noctalia. I used distros before for around 2-3 years when I was studying. Now, I'm transitioning to writing my own config using [Kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) as a base config. See my [dotfiles](https://github.com/nadvent/dotfiles) for my other config files.

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

1. **Native Package Management (`vim.pack`)**: All plugins are declared and managed directly through Neovim 0.12's native package manager (`vim.pack.add`).
2. **~80ms Startup**: Optimized with `vim.loader.enable()`, deferred DAP/Mason initialization, on-demand UI loaders, and lazy filetype modules.
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

Please refer to `/lua/core/keymaps.lua` for an _almost_ complete list of available keymaps. Below is a sheet that roughly covers how to use keymaps.

### Which-Key Groups Cheat Sheet

| Which-Key Group                     | Description                                                         | Keymaps & Examples                                                                                                                                                                                                                                                                                                                |
| :---------------------------------- | :------------------------------------------------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`<leader>a`**<br>`AI Assistant`   | Sidekick AI CLI integration, prompt templates, and session controls | • `<C-.>` Focus assistant terminal<br>• `<leader>aa` Toggle Sidekick CLI float<br>• `<leader>ac` Toggle Gemini directly<br>• `<leader>at` Send `{this}` context<br>• `<leader>av` Send visual selection<br>• `<leader>ap` Select prompt template                                                                                  |
| **`<leader>b`**<br>`Buffers`        | Buffer switching, listing, and layout-preserving deletion           | • `<leader>bb` / `<leader>,` List and switch buffers via Telescope<br>• `<leader>`\` Switch to alternate (last active) buffer<br>• `<leader>bd` Delete buffer safely without breaking splits (`mini.bufremove`)<br>• `<leader>bD` Force delete buffer                                                                             |
| **`<leader>c`**<br>`Code / LSP`     | Formatting, symbol outline trees, and LSP definition panes          | • `<leader>cf` Format buffer (Conform with LSP fallback)<br>• `<leader>cd` Show line diagnostics in floating window<br>• `<leader>cs` Toggle symbol outline tree (Trouble)<br>• `<leader>cl` Toggle LSP definitions & references pane (Trouble)                                                                                   |
| **`<leader>d`**<br>`Debug`          | nvim-dap debugger execution, breakpoints, and UI toggle             | • `<leader>dc` / `<F5>` Start or continue debugging<br>• `<leader>db` / `<leader>dB` Toggle breakpoint / conditional breakpoint<br>• `<leader>di` / `<F1>` Step into; `<leader>do` / `<F2>` Step over; `<leader>dO` / `<F3>` Step out<br>• `<leader>du` / `<F7>` Toggle debug UI (`dapui`)                                        |
| **`<leader>f`**<br>`Files / Find`   | New file creation and terminal file manager integration             | • `<leader>ff` Open Yazi file manager at current file<br>• `<leader>fF` Open Yazi at project root (CWD)<br>• `<leader>fn` Create new empty buffer                                                                                                                                                                                 |
| **`<leader>g`**<br>`Git`            | LazyGit terminal, commit history logs, and branch switching         | • `<leader>gg` Open LazyGit floating terminal<br>• `<leader>gs` Git status & changed files picker (Telescope)<br>• `<leader>gl` / `<leader>gL` Git commit log / active buffer commits<br>• `<leader>gb` List and checkout branches                                                                                                |
| **`<leader>h`**<br>`Git Hunks`      | Gitsigns hunk staging, resetting, inline previews, and diffing      | • `<leader>hs` / `<leader>hr` Stage / reset hunk (or visual selection)<br>• `<leader>hp` / `<leader>hi` Preview hunk (floating popup / inline)<br>• `<leader>hb` Show full git blame for current line<br>• `<leader>hd` / `<leader>hD` Diff against index / last commit<br>• `ih` Text object to operate on inside git hunk       |
| **`<leader>q`**<br>`Session / Quit` | Persistence session restoration, saving controls, and quitting      | • `<leader>qs` Restore session for current working directory<br>• `<leader>ql` Restore last active session<br>• `<leader>qS` Select from saved sessions<br>• `<leader>qq` Quit all windows and exit (`:qa`)                                                                                                                       |
| **`<leader>r`**<br>`Run / Overseer` | Task runner execution, task actions, and fast re-runs               | • `<leader>rr` Run task from templates (`:OverseerRun`)<br>• `<leader>rt` Toggle task runner status panel<br>• `<leader>or` Rerun most recent successful task                                                                                                                                                                     |
| **`<leader>s`**<br>`Search`         | Telescope fuzzy finding for files, grep, help tags, and configs     | • `<leader><Space>` / `<leader>sf` Find files in workspace<br>• `<leader>sg` Live grep across project files<br>• `<leader>sw` Grep word under cursor (or visual selection)<br>• `<leader>/` Fuzzy search within current buffer<br>• `<leader>sn` Search Neovim configuration files<br>• `<leader>sr` Resume previous search query |
| **`<leader>t`**<br>`Toggles`        | Quick inline toggles for Git virtual text annotations               | • `<leader>tb` Toggle virtual text git blame on current line<br>• `<leader>tw` Toggle intra-line word diff                                                                                                                                                                                                                        |
| **`<leader>u`**<br>`UI / Settings`  | Editor display toggles, syntax inspection, and plugin UI            | • `<leader>uw` Toggle line wrap<br>• `<leader>ul` Toggle relative line numbers<br>• `<leader>ud` Toggle inline diagnostics on/off<br>• `<leader>uc` Toggle conceal level (0 ↔ 2)<br>• `<leader>ur` Redraw screen & clear search highlights<br>• `<leader>uP` Open package manager UI (`:Pack`)                                    |
| **`<leader>w`**<br>`Windows`        | Split creation, resizing, and window balancing                      | • `<leader>-` Split window horizontally (below)<br>• `<leader>\|` Split window vertically (right)<br>• `<leader>wd` Close active window split<br>• `<leader>w=` Balance window sizes equally                                                                                                                                      |
| **`<leader>x`**<br>`Diagnostics`    | Project-wide diagnostics, quickfix, and location lists              | • `<leader>xx` / `<leader>xX` Workspace / buffer diagnostics (Trouble)<br>• `<leader>xq` / `<leader>xl` Toggle quickfix list / location list window<br>• `<leader>xD` Send buffer diagnostics to location list                                                                                                                    |
| **`<leader><Tab>`**<br>`Tabs`       | Tab creation, navigation, and tab closing                           | • `<leader><Tab><Tab>` Open new tab<br>• `<leader><Tab>d` Close active tab<br>• `<leader><Tab>o` Close other tabs<br>• `<leader><Tab>]` / `[` Go to next / previous tab                                                                                                                                                           |
| **`g`**<br>`Goto`                   | Code definitions, symbols, and fast comment insertion               | • `gd` Goto definition via Telescope<br>• `gO` Document symbols outline picker<br>• `gW` Dynamic workspace symbols search<br>• `gco` / `gcO` Add comment line below / above                                                                                                                                                       |
| **`gr`**<br>`LSP Actions`           | Language server cross-references and implementations                | • `grr` Goto references via Telescope<br>• `gri` Goto interface implementations<br>• `grt` Goto type definitions                                                                                                                                                                                                                  |

## Core Non-Leader Keymaps

| Category                  | Keymaps                                                                                                               | Description / Example                                                                                                                                                                                                                                                                                                                                                                                         |
| :------------------------ | :-------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Navigation & Jumps**    | `s` / `S`<br>`r` / `R`<br>`]c` / `[c`<br>`]d` / `[d`<br>`[b` / `]b` (or `<S-h>` / `<S-l>`)                            | • `s` / `S`: Flash 2-char jump / treesitter node jump<br>• `r` / `R`: Remote Flash / treesitter search in operator mode<br>• `]c` / `[c`: Jump to next / previous git change<br>• `]d` / `[d`: Jump to next / previous diagnostic (`]e` error, `]w` warning)<br>• `[b` / `]b`: Previous / next open buffer                                                                                                    |
| **Window Focus & Sizing** | `<C-h>` `<C-j>` `<C-k>` `<C-l>`<br>`<C-Up>` `<C-Down>` `<C-Left>` `<C-Right>`                                         | • `<C-h/j/k/l>`: Navigate directly to left/down/up/right split<br>• `<C-Arrows>`: Resize active split height/width by ±2 lines/columns                                                                                                                                                                                                                                                                        |
| **Editing & Ergonomics**  | `<C-s>`<br>`<A-j>` / `<A-k>`<br>`p` (visual)<br>`<` / `>` (visual)<br>`,` `.` `;` (insert)<br>`<Esc><Esc>` (terminal) | • `<C-s>`: Save file from insert, normal, or visual mode<br>• `<A-j>` / `<A-k>`: Bubble current line or visual selection up / down<br>• `p`: Paste visual selection without replacing clipboard contents<br>• `<` / `>`: Indent selection left/right and retain visual highlight<br>• `,` `.` `;`: Create automatic undo breakpoints while typing<br>• `<Esc><Esc>`: Exit terminal insert mode (`<C-\><C-n>`) |

---

## Custom Integrations & Technical Highlights

### 1. Native `blink.cmp` Provider for Overseer Forms

Overseer opens a floating input buffer when configuring tasks with parameters, setting `vim.bo.omnifunc = "v:lua.overseer_form_omnifunc"`. Native Blink source (`blink-overseer`) directly in `plugins/code.lua`:

- Dynamically executes Overseer's omnifunc to fetch enum values (`clang`, `gcc`, `Debug`, `Release`).
- Prioritize Overseer choices for autocompletion
- Uses dynamic source evaluation (`sources.default = function()`) to mute LSP and snippets inside the form, presenting an isolated completion list.

### 2. Dynamic CMake Target Generator

The Overseer template in `overseer/template/user/cmake_build_run.lua` is written as an `overseer.TemplateFileProvider`:

- Reads `CMakeLists.txt` via Lua pattern matching to extract active executable targets.
- Dynamically injects dedicated build-and-run tasks for each detected target into the `:OverseerRun` menu.
- Provides a fallback runner using `find` so built binaries execute reliably regardless of build directory naming.

### 3. Noctalia Dynamic Theme Profile

Set up a toggleable profile to switch to Noctalia's M3 Material palette generator based on Ghostty's palette (not the Base16 matugen for nvim).

- Uses [Dayfox](https://github.com/edeneast/nightfox.nvim) theme as a base.
- Sets transparency to groups like Winbar, Bufferline, Statusline, and Neovim's background.
- Sets colour for Vim modes in statusline, background colours for pickers, and many more.

---

- Native statusline with separate User events so that `vim.cmd 'redrawstatus'` does not recalculate on every generic event.
