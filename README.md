# dotfiles

`~/.config` for an Arch + Wayland machine. Niri, fish, Helix, Ghostty — all on one
e-ink-inspired palette generated from a single file.

## Layout

| | |
|---|---|
| `theme/` | the palette and its build script — **start here**, see `theme/README.md` |
| `niri/` `waybar/` `mako/` `jay/` | Wayland compositor, bar, notifications |
| `fish/` | shell: config, functions, completions |
| `helix/` `ghostty/` | editor and terminal, with themes |
| `yazi/` `btop/` `glow/` `lazygit/` `hunk/` `spotify-player/` | TUI tools |
| `glide/` | Glide browser config (TypeScript); the profile is not tracked |
| `systemd/user/` | user units, plus the `.wants` symlinks recording what is enabled |
| `wireplumber/` `environment.d/` | audio codecs, NVIDIA offload |

## Setup on a new machine

```fish
git clone git@github.com:lnk00/dotfiles.git ~/.config
cd ~/.config
git config core.hooksPath .githooks   # hooks are not cloned; this is per-clone
systemctl --user daemon-reload
python3 theme/build.py --check        # confirm the palette is applied
```

## The theme system

One palette in `theme/eink.toml` renders into ~37 targets across thirteen
applications. Edit that file, then `python3 theme/build.py`. Never hand-edit a
generated file — the next build overwrites it.

The `pre-commit` hook runs `theme/build.py --check` and refuses a commit if any
generated file has drifted. Bypass once with `git commit --no-verify`.

`*.pre-eink` files are the untouched originals from before the palette was
applied, kept as the per-app revert path. `theme/README.md` explains the rest.

## What is deliberately not tracked

`.gitignore` is **deny-by-default**: everything is ignored, and each config is
opted in explicitly. A newly installed app drops its files into `~/.config`
without ever appearing in `git status`.

That is on purpose — this repo is public, and `~/.config` holds live
credentials:

- `gh/hosts.yml` — GitHub OAuth token (`gh/config.yml` is tracked; the token file is not)
- `pulse/cookie` — PulseAudio auth cookie
- `go/telemetry/` — including an upload token

plus a 255 MB browser profile (`glide/glide/`), `glide/glide.d.ts` (generated),
`dconf/user` (binary), `okularrc` (recent-files list), `fish/fish_variables`
(machine-local `$fish_user_paths`) and `hunk/state.json` (version cache).

To add a new config, un-ignore the directory *and* its contents:

```gitignore
!/foo/
!/foo/**
```

A negation cannot re-include a file whose parent directory is still ignored —
that is why every entry comes in pairs. Check the result before committing:

```fish
git add -A --dry-run
```
