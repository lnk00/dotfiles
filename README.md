# dotfiles

`$HOME` for a Void Linux + Wayland machine. Jay, bash, Neovim, Alacritty and
qutebrowser, all on an e-ink-inspired monochrome palette.

## Layout

| | |
|---|---|
| `.bashrc` `.bash_profile` `.inputrc` | shell: aliases, PATH, and the dbus + pipewire session bootstrap |
| `.gitconfig` | identity and GPG signing |
| `.config/jay/` `.config/mako/` | Wayland compositor and notifications |
| `.config/alacritty/` `.config/nvim/` | terminal and editor, with themes |
| `.config/starship/` `.config/lazygit/` | prompt and git TUI |
| `.config/qutebrowser/` | browser: config, per-site permissions, quickmarks |
| `.config/wireplumber/` | bluetooth audio codecs |
| `.config/packages.txt` | every explicitly installed xbps package |

## Setup on a new machine

`$HOME` already exists on a fresh install, so `git clone` into it will refuse.
Attach a repo to the existing directory instead:

```bash
cd ~
git init -b main
git remote add origin git@github.com:lnk00/dotfiles.git
git fetch origin
git checkout -f main                  # -f: overwrite the distro defaults
```

`checkout -f` overwrites any `$HOME` file this repo tracks and leaves everything
else alone. Run `git checkout main` first without `-f` to see what it would
clobber — it will include `.bashrc`, `.bash_profile`, `.inputrc` and
`.gitconfig`.

Two things do not travel with the files:

- `.gitconfig` names GPG `signingkey = 6A1D9A8390E3D6F4` and sets
  `commit.gpgsign = true`. Import the key, or every commit fails until you
  clear those two lines.
- `.bash_profile` starts pipewire and a dbus session bus by hand, because
  nothing else does on a bare Void install. It assumes `pipewire`,
  `pipewire-pulse` and `wireplumber` are on `PATH`.

Restore the package set:

```bash
sudo xbps-install -Sy $(cat ~/.config/packages.txt)
```

That is the `import-package` alias in `.bashrc`; `export-package` regenerates
the list from what is currently installed.

## What is deliberately not tracked

`.gitignore` is **deny-by-default**: everything under `$HOME` is ignored, and
each config is opted in explicitly. A newly installed app drops its files into
`~/.config` without ever appearing in `git status`.

To add a new config, un-ignore the directory *and* its contents:

```gitignore
!/.config/foo/
!/.config/foo/**
```

A negation cannot re-include a file whose parent directory is still ignored —
that is why every entry comes in pairs, and why `/.config/` itself has to be
un-ignored before anything beneath it can be. Check the result before
committing:

```bash
git add -A --dry-run
```

Held out on purpose: `.config/gh` (`hosts.yml` is a live OAuth token),
`.config/github-copilot` (`auth.db` is a Copilot token), `.config/pulse` (binary
auth cookie), `.config/go` (telemetry cache), `.config/qutebrowser/qsettings`
(Qt window geometry), and `.ssh` / `.gnupg` / `.claude`, which hold keys.
