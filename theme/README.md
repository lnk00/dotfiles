# e-ink

One palette, fifteen applications. Two polarities.

```
~/.config/theme/eink.toml       <- the light palette; the file you edit
~/.config/theme/eink-dark.toml  <- the same system after dark
~/.config/theme/build.py        <- renders whichever is active into everything else
~/.config/theme/wallpaper.py    <- re-inks the desktop plate for the dark palette
~/.config/theme/active          <- written by build.py: which one is on disk
```

Change a value, then:

```fish
python3 ~/.config/theme/build.py            # rebuild the active palette
python3 ~/.config/theme/build.py dark       # switch the machine to dark
python3 ~/.config/theme/build.py light      # switch it back
python3 ~/.config/theme/build.py --check    # report drift, write nothing
python3 ~/.config/theme/build.py --audit    # assert every colour on disk is from the ramp
```

One palette is live at a time. Both write the same files under the same theme
names, so switching is a rebuild rather than a second set of themes to keep in
sync — and `--check` and `--audit` read `active` so they compare against
whichever palette actually produced what is on disk.

Applications differ in how fast they notice. Ghostty, Helix, Neovim, yazi and
mako reload on their next launch; niri and waybar want a restart of the bar.

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
| glide   | `glide/config/eink.glide.ts`, `glide/config/blank.html` |
| gtk     | `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini` |

Files only partly ours. The theme lives between `>>> eink theme >>>` markers,
or in one exact key; everything you wrote around it survives a rebuild.

| target | what is touched |
|---|---|
| mako   | the three colour keys, plus urgency sections in a marked block |
| niri   | `active-color`, `inactive-color`, `urgent-color`, `backdrop-color` |
| jay    | the eight keys of `[theme]` |
| hunk   | `[themes.eink]` block, and `theme =` |
| glide  | one `glide.include` line in `glide.ts` |
| niri   | the `swaybg` line, pointed at the palette's own wallpaper |
| nvim   | one `colorscheme` line in `init.lua` |

Plus the `theme = ...` line in helix, ghostty, btop, spotify and glow.

## Reverting

`~/.config` is a git repository and every target is tracked in it, which is the
whole backup story:

```fish
git -C ~/.config checkout -- mako/config
```

The build used to leave a `<name>.pre-eink` copy beside every file it touched.
That is gone: it put a second stale copy of every config on disk to duplicate
what git already held, and it was not even reliable — several of those copies
had been taken *after* a build and contained the theme they claimed to predate.

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

## Dark

`eink-dark.toml` keeps every one of those rules and changes exactly one thing:
polarity. Its role table is the light one mirrored through the middle of the
ramp — level *n* becomes 15 − *n* — so the two modes cannot drift apart, and
every emitter in `build.py` is written in role names only, which is why none of
them needed a line changed to gain a dark theme.

What is *not* mirrored, and why:

- **Chroma at paper**, 0.016 rather than 0.0217. At L 0.195 the light number
  lands in olive, and a background has nothing beside it to correct the eye.
- **`l_max` 0.915, not 1.0.** White text on a near-black field haloes; that is
  the emissive counterpart of the ghosting that kept ink off black in daylight.
  End-to-end range comes out 14.22:1 against the light palette's 14.15:1.
- **The accents.** Same two hues, and the same contrast ratios against paper
  (7.35:1 and 4.83:1), so an error is exactly as loud at night as at noon and
  the 1.52:1 luminance separation between the two survives. Their chroma is
  raised — at these luminances the light values read as dirty white.

It is worth saying plainly that this is not an E Ink palette: a reflective
panel has no light of its own to withhold, so there is no dark Carta page. What
carries over is the discipline, not the device.

## What the rest of the desktop is told

Two targets are not really files, and both exist for the same reason: a palette
that stops at the window frame is not a theme. The bar, the editor and the
terminal can all turn over while every website on the machine stays white.

- **`org.gnome.desktop.interface color-scheme`**, set with `gsettings` to
  `prefer-dark` or `prefer-light`. GTK reads it directly, and
  xdg-desktop-portal republishes it as `org.freedesktop.appearance
  color-scheme` — which is where a browser looks to decide what
  `prefers-color-scheme` means for every page it renders. It is read before it
  is written, so `--check` can report it as drift without touching it, and a
  no-op build does not wake every listener on the bus.
- **Glide's content prefs**, emitted into `eink.glide.ts`:
  `layout.css.prefers-color-scheme.content-override` and
  `browser.theme.content-theme` are set to *follow the system*, and
  `ui.systemUsesDarkTheme` states the answer outright. That last one is the
  belt: niri starts no desktop portal on its own, and without it every
  website's colour would depend on whether a D-Bus service happened to be up.

Sites that support dark mode follow this. Sites that don't are still white,
because the alternative is forcing a colour scheme on pages that never designed
for one — a browsing decision, not a theme one.

## The wallpaper

The desktop shows through window gaps and behind the overview, so it is a
themed surface like any other and each palette names its own plate in
`[wallpaper]`. `build.py` points niri's swaybg line at whichever is active.

There is no dark version of this painting to go and find — it is ink on cream
stock, and cream stock is what it is. So `wallpaper.py` derives one:

```fish
python3 ~/.config/theme/wallpaper.py    # only needed if the dark palette moves
```

It reads the daylight plate as a single channel of ink density, inverts it in
oklab L rather than in sRGB bytes (inverting the stored bytes drags the mist —
which is most of this picture — far too bright), and re-inks it onto the dark
palette's own ramp between `paper` and `faint`.

Two decisions in there are worth keeping if it is ever regenerated:

- **The ceiling is `faint`, not `ink`.** Inversion does something the original
  never did: in daylight the bright mass is the field and the ink is sparse, so
  flipping it makes the mountains the bright mass and a window ends up sitting
  on a glowing white slab. Held at `faint` they come back as mist, which is
  what the palette says decoration is for.
- **There is grain on it.** Ceilinged that low the whole image lives inside
  about twenty-three 8-bit codes, and a sky crossing one code every sixty
  pixels is exactly the shape that bands. The noise puts the transition back
  under the threshold. That it also reads as the tooth of the paper is luck.

Note which way the derivation runs in each mode. In daylight the palette comes
from the wallpaper — `l_max` *is* the painting's field colour. After dark the
wallpaper comes from the palette. Same two things, agreeing from either end.
