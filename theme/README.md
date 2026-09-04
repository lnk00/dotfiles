# e-ink

One palette, fifteen applications.

```
~/.config/theme/eink.toml     <- the only file you edit
~/.config/theme/build.py      <- renders it into everything else
```

Change a value, then:

```fish
python3 ~/.config/theme/build.py            # apply everywhere
python3 ~/.config/theme/build.py --check    # report drift, write nothing
python3 ~/.config/theme/build.py --audit    # assert every colour on disk is from the ramp
```

`--check` exits non-zero if any target has drifted from the palette, so it
works as a pre-commit hook once these files are in a dotfiles repo.

## What is generated

Files written whole. Editing one is pointless; it is overwritten on the next
build.

| target | file |
|---|---|
| helix   | `helix/themes/eink.toml` |
| nvim    | `nvim/colors/eink.lua` |
| ghostty | `ghostty/themes/E-Ink` |
| yazi    | `yazi/theme-eink.toml`, copied to `yazi/theme.toml` |
| btop    | `btop/themes/eink.theme` |
| lazygit | `lazygit/config.yml` |
| spotify | `spotify-player/theme.toml` |
| glow    | `glow/eink.json` |
| fish    | `fish/conf.d/eink-theme.fish` |
| glide   | `glide/config/eink.glide.ts` |

Files only partly ours. The theme lives between `>>> eink theme >>>` markers,
or in one exact key; everything you wrote around it survives a rebuild.

| target | what is touched |
|---|---|
| mako   | the three colour keys, plus urgency sections in a marked block |
| niri   | `active-color`, `inactive-color`, `urgent-color`, `backdrop-color` |
| jay    | the eight keys of `[theme]` |
| hunk   | `[themes.eink]` block, and `theme =` |
| glide  | one `glide.include` line in `glide.ts` |
| nvim   | one `colorscheme` line in `init.lua` |

Plus the `theme = ...` line in helix, ghostty, btop, spotify and glow.

## Reverting

Every file was copied to `<name>.pre-eink` the first time it was touched, and
those copies are never overwritten. To put one application back:

```fish
mv ~/.config/mako/config.pre-eink ~/.config/mako/config
```

The previous monochrome themes are untouched and still selectable:
`monochrome-light` in Helix, `Monochrome Light` in Ghostty,
`yazi/theme-light.toml`.

Neovim is the exception, since it had no theme before this one: reverting it is
deleting the marked block in `nvim/init.lua`, which puts it back on Neovim's
own `default`.

## The rules the palette encodes

An E Ink Carta panel is a 4-bit device: sixteen gray levels, no more. It is
reflective rather than emissive, so its range is roughly 15:1 instead of the
19:1 an LCD gets from black on white. Large fills ghost when they repaint.

Paper here is matched to the desktop wallpaper — an ink-wash painting on warm
cream stock whose field colour measures #fffaea. The cast tapers: chroma runs
from 0.0217 at paper down to 0.0030 at ink, so the page is cream while the text
on it stays near-neutral, the way ink behaves on real stock. Range is 14.15:1,
looser than the 12.13:1 of the original Carta tuning — the cost of matching a
bright wallpaper rather than simulating a reflective panel.

So: every colour is a step on one 16-level ramp; the range stops at 14.15:1;
hue exists only as two accents that are also separated by luminance, so they
survive being read as pure gray; and contrast is carried by weight, rule and
proofreader's mark rather than by slabs of fill.

The ramp is derived from four numbers in `[ramp]`, not stored. Change `l_min`
and every surface on the machine moves together in one command.
