# kickstart.nvim

## Introduction

My (WIP) neovim setup documentation that I use with Niri + Noctalia. I used distros before (e.g. [LunarVim](https://github.com/lunarvim/lunarvim) and [LazyVim](https://www.lazyvim.org/)) before for my studies in college - where I didn't even have a laptop, just used Termux - and university. After awhile, there's a lot of features that are built into neovim itself, I changed to [Zed](https://zed.dev/). It's pretty good, but I have some time to kill, so I thought why not write my neovim config from scratch this time for self-learning.

## Installation

### Install Kickstart 

Follow the steps at [Kickstart](https://github.com/nvim-lua/kickstart.nvim)

</details>

<details><summary>Homebrew</summary>

[Homebrew](https://brew.sh) is a package manager popular on Mac and Linux.
Simply install using [`brew install`](https://formulae.brew.sh/formula/neovim).

</details>

<details><summary>Flatpak</summary>

Flatpak is a package manager for applications that allows developers to package their applications
just once to make it available on all Linux systems. Simply [install flatpak](https://flatpak.org/setup/)
and setup [flathub](https://flathub.org/setup) to [install neovim](https://flathub.org/apps/io.neovim.nvim).

</details>

<details><summary>asdf and mise-en-place</summary>

[asdf](https://asdf-vm.com/) and [mise](https://mise.jdx.dev/) are tool version managers,
mostly aimed towards project-specific tool versioning. However both support managing tools
globally in the user-space as well:

<details><summary>mise</summary>

[Install mise](https://mise.jdx.dev/getting-started.html), then run:

```bash
mise plugins install neovim
mise use neovim@stable
```

</details>

<details><summary>asdf</summary>

[Install asdf](https://asdf-vm.com/guide/getting-started.html), then run:

```bash
asdf plugin add neovim
asdf install neovim stable
asdf set neovim stable --home
asdf reshim neovim
```

</details>

</details>
