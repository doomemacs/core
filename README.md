> [!CAUTION]
> **`doomemacs.com` is not associated with nor endorsed by this project!**
> `doomemacs.org` is our one and only domain. [Read our announcement about it
> here](https://github.com/orgs/doomemacs/discussions/129).

-----

<div align="center">

# Doom Emacs

[Install](#install) • [Documentation] • [FAQ] • [Screenshots] • [Contribute](#contribute)

![Made with Doom Emacs](https://img.shields.io/github/tag/doomemacs/core.svg?style=flat-square&label=release&color=58839b)
![Supports Emacs 27.1–31.1](https://img.shields.io/badge/Supports-Emacs_27.1–31.1-blueviolet.svg?style=flat-square&logo=GNU%20Emacs&logoColor=white)
![Latest commit](https://img.shields.io/github/last-commit/doomemacs/core?style=flat-square)
<!-- ![Build status: master](https://img.shields.io/github/workflow/status/doomemacs/core/CI/master?style=flat-square) -->
[![Discord Server](https://img.shields.io/discord/406534637242810369?color=738adb&label=Discord&logo=discord&logoColor=white&style=flat-square)][discord]
[![Github Discussions](https://img.shields.io/github/discussions/doomemacs/community?label=Discussions&logo=github&style=flat-square)][discuss]

![Doom Emacs Screenshot](https://raw.githubusercontent.com/doomemacs/core/screenshots/main.png)

</div>

---

### Table of Contents
- [Introduction](#introduction)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Install](#install)
- [Roadmap](#roadmap)
- [Getting help](#getting-help)
- [Contribute](#contribute)


# Introduction
<a href="http://ultravioletbat.deviantart.com/art/Yay-Evil-111710573">
  <img src="https://raw.githubusercontent.com/doomemacs/core/screenshots/cacochan.png" align="right" />
</a>

> It is a story as old as time. A stubborn, shell-dwelling, and melodramatic
> vimmer—envious of the features of modern text editors—spirals into
> despair before he succumbs to the [dark side][evil-mode]. This is his config.

Doom is a configuration framework for [GNU Emacs] tailored for Emacs bankruptcy
veterans who want less framework in their frameworks, a modicum of stability
(and reproducibility) from their package manager, and the performance of a hand
rolled config (or better). It can be a foundation for your own config or a
resource for Emacs enthusiasts to learn more about our favorite operating
system.

Its design is guided by these mantras:

+ **Gotta go fast.** Startup and run-time performance are priorities. Doom goes
  beyond by modifying packages to be snappier and load lazier.
+ **Close to metal.** There's less between you and vanilla Emacs by design.
  That's less to grok and less to work around when you tinker. Internals ought
  to be written as if reading them were part of Doom's UX, and it is!
+ **Opinionated, but not stubborn.** Doom is about reasonable defaults and
  curated opinions, but use as little or as much of it as you like.
+ **Your system, your rules.** You know better. At least, Doom hopes so! It
  won't *automatically* install system dependencies (and will force plugins not
  to either). Rely on `doom doctor` to tell you what's missing.
+ **Nix/Guix is a great idea!** The Emacs ecosystem is temperamental. Things
  break and they break often. Disaster recovery should be a priority! Doom's
  package management should be declarative and your private config reproducible,
  and comes with a means to roll back releases and updates (still a WIP).
  
Check out [the FAQ][FAQ] for answers to common questions about the project.


# Features
- Minimalistic good looks inspired by modern editors.
- Curated and sane defaults for many packages, (major) OSes, and Emacs itself.
- A modular organizational structure for separating concerns in your config.
- A standard library designed to simplify your elisp bike shedding.
- A declarative [package management system][package-management] (powered by
  [straight.el]) with a command line interface. Install packages from anywhere,
  not just (M)ELPA, and pin them to any commit.
- Optional vim emulation powered by [evil-mode], including ports of popular vim
  plugins like [vim-sneak], [vim-easymotion], [vim-unimpaired] and
  [more][ported-vim-plugins]!
- Opt-in LSP integration for many languages, using [lsp-mode] or [eglot]
- Support for *many* programming languages. Includes syntax highlighting,
  linters/checker integration, inline code evaluation, code completion (where
  possible), REPLs, documentation lookups, snippets, and more!
- Support for *many* tools, like docker, pass, ansible, terraform, and more.
- A Spacemacs-esque [keybinding scheme][bindings], centered around leader
  and localleader prefix keys (<kbd>SPC</kbd> and <kbd>SPC</kbd><kbd>m</kbd> for
  evil users, <kbd>C-c</kbd> and <kbd>C-c l</kbd> for vanilla users).
- A rule-based [popup manager][popup-system] to control how temporary buffers
  are displayed (and disposed of).
- Per-file indentation style detection and [editorconfig] integration. Let
  someone else argue about tabs vs **_spaces_**.
- Project-management tools and framework-specific minor modes with their own
  snippets libraries.
- Project search (and replace) utilities, powered by [ripgrep] and [ivy] or
  [helm].
- Isolated and persistent workspaces (also substitutes for vim tabs).
- Support for Chinese and Japanese input systems.
- Save a snapshot of your shell environment to a file for Emacs to load at
  startup. No more struggling to get Emacs to inherit your `PATH`, among other
  things.


# Prerequisites
- **Required:**
  - GNU Emacs 27.1–31.1 (31.1 is recommended)
    - Using only Doom's CLI requires 27.1+
    - Using Doom as a starter kit requires 29.1+
  - Git >= 2.23
  - [ripgrep] >= 11.0
- **Optional, but recommended:**
  - [fd] 7.3.0+ (used to improve file indexing performance)
  - GNU variants of `find`, `ls`, and `tar` (on MacOS and BSD *nix)
  - Symbola font (Emacs' fallback font for glyphs it can't display)

> [!WARNING]
> **Avoid unstable and pre-release builds of Emacs.** These end in `.50`, `.60`,
> or `.9X` (e.g. `28.1.91`). Doom should generally work on Emacs HEAD (the
> maintainer dogfoods it), but support lags behind the bleeding edge by at least
> a month or so.
 
> [!IMPORTANT]
> Doom is comprised of [~150 optional modules][Modules], some of which may have
> additional dependencies. [Visit their documentation][Modules] or run `bin/doom
> doctor` to check for any that you may have missed.


# Install

### Experimental Windows installer

The proposed per-user Windows x86_64 installer under [`installer/`](installer/)
bundles Emacs, Git, ripgrep, fd and a native compilation toolchain. Internet
access is required for the first package sync. This is an experimental packaging
workflow, not a published or supported installer release. See
[`installer/README.org`](installer/README.org) for build instructions, validation
and known limitations.

Run the setup executable to install. Run it again to choose **Reinstall / repair**
or **Uninstall Doom Emacs and its bundled tools**. Removal keeps your configuration
in `%USERPROFILE%\.config\doom` and tools installed separately. Windows Settings
also provides an uninstall entry. Incomplete installations from the first build
are recognized and their removal metadata is recovered automatically.
The installer and removal windows show the full configuration paths, flag a
missing configured folder, and list an existing `.doom.d` separately. Keeping
configuration means leaving those files in place; no backup copy is created.
Location fields can be selected and copied with Ctrl+A / Ctrl+C.

The installer adds `%LOCALAPPDATA%\Programs\DoomEmacs\bin` (or the selected install
root's `bin`) to your user PATH. Run `doom doctor` in PowerShell or CMD afterward.
If an existing terminal cannot find `doom`, fully close and reopen the terminal
application, including Windows Terminal. `doom-emacs` starts the GUI.

For unattended removal, use `DoomEmacs-…-setup.exe /S /Uninstall`.
`/NoShortcuts` suppresses shortcut creation during unattended installation.
To inspect recovery of an old incomplete installation without changing it:

```powershell
.\installer\repair-doom.ps1 -InstallRoot "$env:LOCALAPPDATA\Programs\DoomEmacs" -WhatIf
```

The installed Doom tree is a snapshot without `.git`, so `doom upgrade` cannot
update the framework. Update this Windows bundle by rerunning a newer installer.
The optional WSL page adds `doom` and `doom-wsl` commands to a selected existing
distribution. They use this Windows installation and configuration. `doom-wsl`
opens Linux files in the Windows GUI; `--wait` supports editor workflows. See
the [bridge documentation](installer/README.org) for requirements and cleanup.

### Standard installation

``` sh
git clone --depth 1 https://github.com/doomemacs/core ~/.config/emacs
~/.config/emacs/bin/doom install
```

Then [read our Getting Started guide][getting-started] to be walked through
installing, configuring and maintaining Doom Emacs.

It's a good idea to add `~/.config/emacs/bin` to your `PATH`! Other `bin/doom`
commands you should know about:

+ `doom sync` to synchronize your private config with Doom by installing missing
  packages, removing orphaned packages, and regenerating caches. Run this
  whenever you modify your private `init.el` or `packages.el`, or install/remove
  an Emacs package through your OS package manager (e.g. mu4e or agda).
+ `doom sync --env` to include a snapshot of your shell environment that Doom
  will load at startup. This allows Emacs to inherit your `PATH`, among other
  things. This replaces
  [exec-path-from-shell](https://github.com/purcell/exec-path-from-shell).
+ `doom upgrade` to update Doom to the latest release & all installed packages.
+ `doom doctor` to diagnose common issues with your system and config.


# Roadmap
Doom is an active and ongoing project. To make that development more
transparent, its roadmap (and other concerns) are published across three github
project boards and a newsletter:

- [Development Roadmap](https://doomemacs.org/roadmap)
- [Packages under review](https://doomemacs.org/packages-under-review):
  lists plugins we are watching and considering for inclusion, and what their
  status for inclusion is. Please consult this list before requesting new
  packages/features.
+ [Upstream bugs](https://github.com/orgs/doomemacs/projects/7): lists
  issues that originate from elsewhere, and whether or not we have local
  workarounds or temporary fixes for them.
+ ~~Doom's newsletter~~ (not finished) will contain changelogs in between
  releases.
  

# Getting help
Emacs is no journey of a mere thousand miles. You _will_ run into problems and
mysterious errors. When you do, here are some places you can look for help:

+ [Our documentation][documentation] covers many use cases.
  + [The Configuration section][configuration] covers how to configure Doom and
    its packages.
  + [The Package Management section][package-management] covers how to install
    and disable packages.
  + [This section][bin/doom] explains the `bin/doom` script's most important
    commands.
  + [This section][common-mistakes] lists some common configuration mistakes new
    users make, when migrating a config from another distro or their own.
  + [This answer][change-theme] shows you how to add your own themes to your
    private config.
  + [This answer][change-font] shows you how to change the default font.
  + Your issue may be documented in the [FAQ].
+ With Emacs built-in help system documentation is a keystroke away:
  + For functions: <kbd>SPC h f</kbd> or <kbd>C-h f</kbd>
  + For variables: <kbd>SPC h v</kbd> or <kbd>C-h v</kbd>
  + For a keybind: <kbd>SPC h k</kbd> or <kbd>C-h k</kbd>
  + To search available keybinds: <kbd>SPC h b b</kbd> or <kbd>C-h b b</kbd>
+ Run `bin/doom doctor` to detect common issues with your development
  environment and private config.
+ Check out the [FAQ] or [Community FAQs][community-faq], in case your question
  has already been answered.
+ Search [Doom's issue tracker](https://github.com/doomemacs/core/issues)
  in case your issue was already reported.
+ Hop on [our Discord server][discord]; it's active and friendly! Keep an eye on
  the #announcements channel, where I announce breaking updates and releases.


# Contribute
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com) 
[![Elisp styleguide](https://img.shields.io/badge/elisp-style%20guide-purple?style=flat-square)](https://github.com/bbatsov/emacs-lisp-style-guide)
[![Donate on liberapay](https://img.shields.io/badge/liberapay-donate-1.svg?style=flat-square&logo=liberapay&color=blue)][liberapay]
[![Donate on paypal](https://img.shields.io/badge/paypal-donate-1?style=flat-square&logo=paypal&color=blue)][paypal]

Doom is a labor of love and incurable madness, but I'm only one guy. Doom
wouldn't be where it is today without your help. I welcome contributions of any
kind!

+ I :heart: pull requests and bug reports (see the [Contributing
  Guidelines][contribute])!
+ Don't hesitate to [tell me my Elisp-fu
  sucks](https://github.com/doomemacs/core/issues/new/choose), but please
  tell me why.
+ Hop on [our Discord server][discord] and say hi! Help others, hang out or talk
  to me about Emacs, gamedev, programming, physics, pixel art, anime, gaming --
  anything you like. Nourish this lonely soul.
+ If you'd like to support my work financially, buy me a drink through
  [liberapay] or [paypal]. My work contends with studies, adventures in indie
  gamedev and freelance work. Donations help me allocate more time to my Emacs
  and OSS capers.
  
## LLM Policy

Generative AI is not used in the development of this project (except to test,
debug, and improve [LLM
modules](https://github.com/doomemacs/modules/tree/main/modules/tools/llm)).
LLM-generated (or assisted) contributions are **highly** discouraged, but
tolerated so long as they meet the following criteria:

1. LLM-generated contributions are small,
2. LLM-use is disclosed,
3. [Issue](https://github.com/doomemacs/.github/blob/main/.github/ISSUE_TEMPLATE/bug_report.yml) and [pull request](https://github.com/doomemacs/.github/blob/main/.github/PULL_REQUEST_TEMPLATE.md) templates are followed (it is disruptive when LLMs omit key information and AI disclosures, or follow arbitrary heading structures),
4. Your `M-x doom/info` must be uploaded as a file, not published as text in the issue/PR.[^1]
5. A human responds to reviews and questions.

Failing that, related issues/PRs will be immediately closed and refused with
notice. Repeat offenders will be banned.

[^1]: A file-upload is used because `doom-info`s are filled with keywords that pollute search engine results and make issues harder for users/maintainers to find.


[contribute]: docs/contributing.org
[discord]: https://discord.doomemacs.org
[discuss]: https://discuss.doomemacs.org
[community-faq]: https://github.com/doomemacs/community?tab=readme-ov-file#frequently-asked-questions
[documentation]: docs/index.org
[faq]: https://github.com/doomemacs/core/blob/master/docs/faq.org
[getting-started]: docs/getting_started.org
[install]: docs/getting_started.org#install
[backtrace]: docs/getting_started.org#how-to-extract-a-backtrace-from-an-error
[configuration]: docs/getting_started.org#configuring-doom
[package-management]: docs/getting_started.org#package-management
[bin/doom]: docs/getting_started.org#the-bindoom-utility
[common-mistakes]: docs/getting_started.org#common-mistakes-when-configuring-doom-emacs
[change-theme]: docs/faq.org#how-do-i-change-the-theme
[change-font]: docs/faq.org#how-do-i-change-the-fonts
[modules]: docs/modules.org
[popup-system]: modules/ui/popup/README.org
[screenshots]: https://github.com/doomemacs/core/tree/screenshots#emacsd-screenshots

[bindings]: modules/config/default/+evil-bindings.el
[editorconfig]: http://editorconfig.org/
[evil-mode]: https://github.com/emacs-evil/evil
[fd]: https://github.com/sharkdp/fd
[gnu emacs]: https://www.gnu.org/software/emacs/
[helm]: https://github.com/emacs-helm/helm
[ivy]: https://github.com/abo-abo/swiper
[lsp-mode]: https://github.com/emacs-lsp/lsp-mode
[eglot]: https://github.com/joaotavora/eglot
[nix]: https://nixos.org
[ported-vim-plugins]: modules/editor/evil/README.org#ported-vim-plugins
[ripgrep]: https://github.com/BurntSushi/ripgrep
[straight.el]: https://github.com/radian-software/straight.el
[vim-easymotion]: https://github.com/easymotion/vim-easymotion
[vim-lion]: https://github.com/tommcdo/vim-lion
[vim-sneak]: https://github.com/justinmk/vim-sneak
[vim-unimpaired]: https://github.com/tpope/vim-unimpaired

[liberapay]: https://liberapay.com/hlissner/donate
[paypal]: https://paypal.me/hlissner/10
