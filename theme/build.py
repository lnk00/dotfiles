#!/usr/bin/env python3
"""
Render the e-ink palette into every themed surface on this machine.

    python3 ~/.config/theme/build.py            # build everything
    python3 ~/.config/theme/build.py --check    # report drift, write nothing

The palette lives in eink.toml next to this file and is the only thing meant
to be edited by hand. Every file this script writes carries a header saying so.

Two kinds of target:

  OWNED    the whole file belongs to the theme (helix, ghostty, yazi, btop,
           spotify, glow, fish). Written wholesale.
  SHARED   the file is the application's own config and only part of it is
           ours (mako, niri, jay, hunk, lazygit, glide, and the `theme = ...`
           assignment lines). Patched surgically, between sentinel markers or
           by exact key, so hand-written settings around them survive.

Every file is copied to `<name>.pre-eink` the first time it is touched, so
reverting is `mv` and nothing here is destructive.
"""
import math, re, shutil, sys, tomllib
from pathlib import Path

CFG   = Path.home() / ".config"
SRC   = CFG / "theme" / "eink.toml"
CHECK = "--check" in sys.argv

# --------------------------------------------------------------------------
# Ramp derivation. The palette file stores four numbers; the 16 gray levels
# are computed here so the parameters stay the single source of truth.
# --------------------------------------------------------------------------

def oklch_to_hex(L, C, h):
    a = C * math.cos(math.radians(h))
    b = C * math.sin(math.radians(h))
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    rgb = (
         4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )
    out = []
    for c in rgb:
        c = max(0.0, min(1.0, c))
        c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
        out.append(max(0, min(255, round(c * 255))))
    return "#%02x%02x%02x" % tuple(out)

def relative_luminance(hexstr):
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (f(int(hexstr[i:i + 2], 16)) for i in (1, 3, 5))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def contrast(a, b):
    la, lb = relative_luminance(a), relative_luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

P = tomllib.load(open(SRC, "rb"))
_r = P["ramp"]
# chroma_min lets the cast taper: strongest at paper, fading toward ink. That
# is how ink on cream stock actually behaves -- the warmth lives in the paper,
# and the ink stays near-neutral. Omit it and chroma is constant, as before.
_c_ink = _r.get("chroma_min", _r["chroma"])
_steps = _r["levels"] - 1
RAMP = [
    oklch_to_hex(_r["l_min"]  + (_r["l_max"]  - _r["l_min"]) * i / _steps,
                 _c_ink       + (_r["chroma"] - _c_ink)      * i / _steps,
                 _r["hue"])
    for i in range(_r["levels"])
]
R       = {name: RAMP[i] for name, i in P["roles"].items()}
ERROR   = P["accents"]["error"]
WARNING = P["accents"]["warning"]

# Bare names so emitters read as prose rather than dictionary lookups.
ink, charcoal, slate, muted = R["ink"], R["charcoal"], R["slate"], R["muted"]
faint, rule, selection      = R["faint"], R["rule"], R["selection"]
highlight, cursorline, paper = R["highlight"], R["cursorline"], R["paper"]

BANNER = "GENERATED from ~/.config/theme/eink.toml by build.py -- do not edit by hand"

# --------------------------------------------------------------------------
# Write / patch helpers
# --------------------------------------------------------------------------

results = []   # (status, target, note)

def _backup(path: Path):
    """Preserve the pre-theme original exactly once. Never overwritten after."""
    bak = path.with_name(path.name + ".pre-eink")
    if path.exists() and not bak.exists() and not CHECK:
        shutil.copy2(path, bak)

def write(path: Path, content: str, label: str):
    """OWNED target: the file belongs to the theme in its entirety."""
    path = Path(path)
    if not content.endswith("\n"):
        content += "\n"
    old = path.read_text() if path.exists() else None
    if old == content:
        results.append(("same", label, str(path)))
        return
    if CHECK:
        results.append(("DRIFT", label, str(path)))
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    _backup(path)
    path.write_text(content)
    results.append(("new" if old is None else "wrote", label, str(path)))

def splice(path: Path, body: str, label: str, comment="#", tag="eink"):
    """
    SHARED target: replace only the region between our sentinels, appending it
    if absent. Everything the user wrote outside the markers is preserved.
    """
    path = Path(path)
    begin = f"{comment} >>> {tag} theme (generated -- edit ~/.config/theme/eink.toml) >>>"
    end   = f"{comment} <<< {tag} theme <<<"
    block = f"{begin}\n{body.strip()}\n{end}"
    original = path.read_text() if path.exists() else ""
    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.S)
    if pattern.search(original):
        updated = pattern.sub(lambda _: block, original)
    else:
        sep = "" if original.endswith("\n") or not original else "\n"
        updated = f"{original}{sep}\n{block}\n"
    if updated == original:
        results.append(("same", label, str(path)))
        return
    if CHECK:
        results.append(("DRIFT", label, str(path)))
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    _backup(path)
    path.write_text(updated)
    results.append(("spliced", label, str(path)))

def set_key(path: Path, pattern: str, replacement: str, label: str):
    """
    Assignment: point an application at its new theme by rewriting one exact
    key, leaving the rest of its config untouched.
    """
    path = Path(path)
    if not path.exists():
        results.append(("MISSING", label, str(path)))
        return
    original = path.read_text()
    updated, n = re.subn(pattern, replacement, original, count=1, flags=re.M)
    if n == 0:
        results.append(("NOKEY", label, f"{path}: /{pattern}/ not found"))
        return
    if updated == original:
        results.append(("same", label, str(path)))
        return
    if CHECK:
        results.append(("DRIFT", label, str(path)))
        return
    _backup(path)
    path.write_text(updated)
    results.append(("assigned", label, str(path)))

# --------------------------------------------------------------------------
# Helix
#
# The scope table addresses the palette by NAME, so only the [palette] block
# is interpolated. That is deliberate: the semantic mapping below is the part
# that was tuned by hand and it must not move when a ramp parameter changes.
# --------------------------------------------------------------------------

HELIX_BODY = '''inherits = "default"

# Interface
"ui.background" = { fg = "ink", bg = "paper" }
"ui.background.separator" = { fg = "rule", bg = "paper" }
"ui.text" = { fg = "ink" }
"ui.text.focus" = { fg = "ink", bg = "highlight", modifiers = ["bold"] }
"ui.text.inactive" = { fg = "muted", bg = "paper" }
"ui.text.info" = { fg = "ink", bg = "highlight", modifiers = ["bold"] }
"ui.text.directory" = { fg = "ink", modifiers = ["bold"] }
"ui.text.symlink" = { fg = "charcoal", modifiers = ["italic"] }

"ui.gutter" = { fg = "muted", bg = "paper" }
"ui.gutter.selected" = { fg = "ink", bg = "cursorline" }
"ui.linenr" = { fg = "muted", bg = "paper" }
"ui.linenr.selected" = { fg = "ink", bg = "cursorline", modifiers = ["bold"] }

# Modes are distinguished by mark, not by fill -- a mode indicator changes on
# every keystroke-level switch, and a colour-swapped slab is exactly the kind
# of small high-frequency repaint that ghosts.
"ui.statusline" = { fg = "ink", bg = "paper", modifiers = ["bold"] }
"ui.statusline.inactive" = { fg = "muted", bg = "paper" }
"ui.statusline.normal" = { fg = "ink", bg = "paper", modifiers = ["bold"] }
"ui.statusline.insert" = { fg = "ink", bg = "paper", modifiers = ["bold"], underline = { color = "ink", style = "line" } }
"ui.statusline.select" = { fg = "ink", bg = "paper", modifiers = ["bold", "italic"] }
"ui.statusline.separator" = { fg = "rule", bg = "paper" }

"ui.bufferline" = { fg = "muted", bg = "paper" }
"ui.bufferline.active" = { fg = "ink", bg = "paper", modifiers = ["bold", "underlined"] }
"ui.bufferline.background" = { fg = "muted", bg = "paper" }
"ui.window" = { fg = "rule", bg = "paper" }
"ui.popup" = { fg = "ink", bg = "paper" }
"ui.popup.info" = { fg = "ink", bg = "paper" }
"ui.help" = { fg = "ink", bg = "paper" }

# Picker headers read as a printed rule rather than a black bar.
"ui.picker.header" = { fg = "ink", bg = "paper", modifiers = ["bold", "underlined"] }
"ui.picker.header.column" = { fg = "muted", bg = "paper", modifiers = ["bold", "underlined"] }
"ui.picker.header.column.active" = { fg = "ink", bg = "paper", modifiers = ["bold", "underlined"] }

"ui.menu" = { fg = "ink", bg = "paper" }
"ui.menu.selected" = { fg = "ink", bg = "highlight", modifiers = ["bold"] }
"ui.menu.scroll" = { fg = "muted", bg = "rule" }

# Primary and secondary selections separate by fill weight, and text stays
# legible inside both.
"ui.selection" = { fg = "ink", bg = "highlight" }
"ui.selection.primary" = { fg = "ink", bg = "selection" }
"ui.highlight" = { fg = "ink", bg = "highlight" }
"ui.cursorline" = { bg = "cursorline" }
"ui.cursorline.primary" = { bg = "cursorline" }
"ui.cursorline.secondary" = { bg = "cursorline" }

# A solid block is the one high-contrast element e-ink renders well: it reads
# as an inked mark. The insert bar needs bg = ink to render at all.
"ui.cursor" = { fg = "paper", bg = "ink" }
"ui.cursor.normal" = { fg = "paper", bg = "ink" }
"ui.cursor.insert" = { fg = "paper", bg = "ink" }
"ui.cursor.select" = { fg = "paper", bg = "charcoal" }
"ui.cursor.match" = { fg = "ink", bg = "highlight", modifiers = ["bold"] }

"tabstop" = { fg = "ink", bg = "highlight" }
"ui.virtual.ruler" = { bg = "highlight" }
"ui.virtual.whitespace" = { fg = "rule" }
"ui.virtual.indent-guide" = { fg = "rule" }
"ui.virtual.inlay-hint" = { fg = "muted", modifiers = ["italic"] }
"ui.virtual.inlay-hint.parameter" = { fg = "muted", modifiers = ["italic"] }
"ui.virtual.inlay-hint.type" = { fg = "slate", modifiers = ["italic"] }
"ui.virtual.wrap" = { fg = "faint" }
# The single deliberate invert in the theme.
"ui.virtual.jump-label" = { fg = "paper", bg = "ink", modifiers = ["bold"] }

# Diagnostics: underline style is the primary carrier, weight second, hue last.
"error" = { fg = "error-red", modifiers = ["bold"], underline = { color = "error-red", style = "curl" } }
"warning" = { fg = "warning-orange", modifiers = ["bold"], underline = { color = "warning-orange", style = "dashed" } }
"info" = { fg = "slate", underline = { color = "slate", style = "dotted" } }
"hint" = { fg = "muted", modifiers = ["italic"] }
"diagnostic.error" = { underline = { color = "error-red", style = "curl" } }
"diagnostic.warning" = { underline = { color = "warning-orange", style = "dashed" } }
"diagnostic.info" = { underline = { color = "slate", style = "dotted" } }
"diagnostic.hint" = { modifiers = ["italic"] }
"diagnostic.unnecessary" = { fg = "muted", modifiers = ["dim"] }
"diagnostic.deprecated" = { fg = "slate", modifiers = ["crossed_out"] }

# Syntax: hierarchy comes from four text tones plus bold and italic.
"attribute" = { fg = "charcoal", modifiers = ["italic"] }
"type" = { fg = "ink", modifiers = ["bold"] }
"type.builtin" = { fg = "ink", modifiers = ["bold", "italic"] }
"type.parameter" = { fg = "charcoal", modifiers = ["italic"] }
"type.enum.variant" = { fg = "charcoal", modifiers = ["bold"] }
"constructor" = { fg = "ink", modifiers = ["bold"] }
"constant" = { fg = "charcoal", modifiers = ["bold"] }
"constant.builtin" = { fg = "ink", modifiers = ["bold", "italic"] }
"constant.character" = { fg = "charcoal" }
"constant.character.escape" = { fg = "ink", modifiers = ["bold"] }
"constant.numeric" = { fg = "charcoal" }
"string" = { fg = "charcoal" }
"string.regexp" = { fg = "ink", modifiers = ["italic"] }
"string.special" = { fg = "ink", modifiers = ["bold"] }
"string.special.path" = { fg = "charcoal", modifiers = ["italic"] }
"string.special.url" = { fg = "ink", underline = { color = "ink", style = "line" } }

"comment" = { fg = "muted", modifiers = ["italic"] }
"comment.documentation" = { fg = "slate", modifiers = ["italic"] }
"comment.unused" = { fg = "muted", modifiers = ["italic", "crossed_out"] }
"variable" = { fg = "ink" }
"variable.builtin" = { fg = "charcoal", modifiers = ["italic"] }
"variable.parameter" = { fg = "charcoal", modifiers = ["italic"] }
"variable.other.member" = { fg = "charcoal" }
"label" = { fg = "ink", modifiers = ["bold"] }
"punctuation" = { fg = "slate" }
"punctuation.delimiter" = { fg = "muted" }
"punctuation.bracket" = { fg = "ink" }
"punctuation.special" = { fg = "charcoal", modifiers = ["bold"] }
"keyword" = { fg = "ink", modifiers = ["bold"] }
"keyword.control" = { fg = "ink", modifiers = ["bold"] }
"keyword.operator" = { fg = "charcoal", modifiers = ["bold"] }
"keyword.directive" = { fg = "charcoal", modifiers = ["bold", "italic"] }
"keyword.function" = { fg = "ink", modifiers = ["bold", "italic"] }
"keyword.storage" = { fg = "ink", modifiers = ["bold"] }
"operator" = { fg = "charcoal", modifiers = ["bold"] }
"function" = { fg = "ink", modifiers = ["bold"] }
"function.builtin" = { fg = "charcoal", modifiers = ["bold", "italic"] }
"function.method" = { fg = "ink", modifiers = ["bold"] }
"function.macro" = { fg = "charcoal", modifiers = ["bold", "italic"] }
"tag" = { fg = "ink", modifiers = ["bold"] }
"tag.attribute" = { fg = "charcoal", modifiers = ["italic"] }
"namespace" = { fg = "charcoal", modifiers = ["italic"] }
"special" = { fg = "ink", modifiers = ["bold"] }

# Markup follows print convention: heading rank descends by weight then tone.
"markup.heading" = { fg = "ink", modifiers = ["bold"] }
"markup.heading.marker" = { fg = "rule" }
"markup.heading.1" = { fg = "ink", modifiers = ["bold", "underlined"] }
"markup.heading.2" = { fg = "ink", modifiers = ["bold"] }
"markup.heading.3" = { fg = "charcoal", modifiers = ["bold"] }
"markup.heading.4" = { fg = "charcoal", modifiers = ["bold", "italic"] }
"markup.heading.5" = { fg = "slate", modifiers = ["bold"] }
"markup.heading.6" = { fg = "slate", modifiers = ["italic"] }
"markup.bold" = { fg = "ink", modifiers = ["bold"] }
"markup.italic" = { fg = "charcoal", modifiers = ["italic"] }
"markup.strikethrough" = { fg = "muted", modifiers = ["crossed_out"] }
"markup.link" = { fg = "ink" }
"markup.link.url" = { fg = "charcoal", underline = { color = "rule", style = "line" } }
"markup.link.label" = { fg = "ink" }
"markup.link.text" = { fg = "ink", underline = { color = "ink", style = "line" } }
"markup.list" = { fg = "slate", modifiers = ["bold"] }
"markup.list.numbered" = { fg = "slate", modifiers = ["bold"] }
"markup.list.unnumbered" = { fg = "slate", modifiers = ["bold"] }
"markup.quote" = { fg = "slate", modifiers = ["italic"] }
"markup.raw" = { fg = "charcoal" }
"markup.raw.inline" = { fg = "charcoal" }
"markup.raw.block" = { fg = "charcoal" }

# Diffs use proofreader's marks. There is no green or red to lean on, and
# grayscale bold-vs-dim alone is too weak to scan down a gutter.
"diff.plus" = { fg = "ink", underline = { color = "ink", style = "line" } }
"diff.minus" = { fg = "slate", modifiers = ["crossed_out"] }
"diff.delta" = { fg = "charcoal", modifiers = ["bold"], underline = { color = "charcoal", style = "dotted" } }
"diff.plus.gutter" = { fg = "ink", modifiers = ["bold"] }
"diff.minus.gutter" = { fg = "slate", modifiers = ["bold"] }
"diff.delta.gutter" = { fg = "charcoal", modifiers = ["bold"] }
'''

def emit_helix():
    lv = {n: i for n, i in P["roles"].items()}
    rows = []
    for name in ("ink", "charcoal", "slate", "muted", "faint", "rule",
                 "selection", "highlight", "cursorline", "paper"):
        c = contrast(R[name], paper)
        grade = "AAA" if c >= 7 else "AA " if c >= 4.5 else "   "
        ratio = "------" if name == "paper" else f"{c:5.2f}:1"
        rows.append(f'{name:<10} = "{R[name]}"  # L{lv[name]:<2} {ratio}  {grade}')
    head = (
        f"# e-ink -- an E Ink Carta panel simulated on an emissive display.\n"
        f"# {BANNER}\n#\n"
        f"# 4-bit panel: 16 gray levels, no more. Reflective, so the range stops\n"
        f"# at {contrast(ink, paper):.2f}:1 -- neither pure white nor pure black appears.\n"
        f"# Paper is matched to the desktop wallpaper exactly. The warm cast\n"
        f"# tapers from chroma {_r['chroma']} at paper to {_c_ink} at ink, so the page is\n"
        f"# cream and the text on it stays near-neutral, as on real stock.\n"
        f"# Large fills ghost on repaint, so weight and rule carry signal, not slabs.\n\n"
    )
    tail = (
        f"\n# {_r['levels']}-step Carta ramp: oklch(L {_r['l_min']} -> {_r['l_max']}, "
        f"C {_r['chroma']}, h {_r['hue']}).\n"
        f"[palette]\n" + "\n".join(rows) + "\n"
        f"# Off-ramp by necessity, and the only hue in the system. Separated by\n"
        f"# luminance ({contrast(ERROR, WARNING):.2f}:1) so they survive being read as pure gray.\n"
        f'error-red      = "{ERROR}"  # {contrast(ERROR, paper):5.2f}:1  AA\n'
        f'warning-orange = "{WARNING}"  # {contrast(WARNING, paper):5.2f}:1  AA-large; always bold + dashed\n'
    )
    write(CFG / "helix/themes/eink.toml", head + HELIX_BODY + tail, "helix")
    set_key(CFG / "helix/config.toml", r'^theme\s*=\s*".*"', 'theme = "eink"', "helix:assign")

# --------------------------------------------------------------------------
# Ghostty
#
# ANSI red and yellow are bound to the two accents, so any CLI that prints an
# error or a warning lands on the same two colours the editor uses. Every
# other slot is a gray. Slot 7 stays light and 15 dark, matching the existing
# Monochrome Light convention on this machine.
# --------------------------------------------------------------------------

def emit_ghostty():
    ansi = [ink, ERROR, charcoal, WARNING, slate, charcoal, slate, rule,
            muted, ERROR, ink, WARNING, ink, slate, muted, ink]
    lines = [f"# E-Ink. {BANNER}",
             "# ANSI red/yellow carry the accents; everything else is the Carta ramp.",
             ""]
    lines += [f"palette = {i}={c}" for i, c in enumerate(ansi)]
    lines += ["",
              f"background = {paper}",
              f"foreground = {ink}",
              f"cursor-color = {ink}",
              f"cursor-text = {paper}",
              f"selection-background = {selection}",
              f"selection-foreground = {ink}"]
    write(CFG / "ghostty/themes/E-Ink", "\n".join(lines), "ghostty")
    set_key(CFG / "ghostty/config.ghostty", r'^theme\s*=.*$', "theme = E-Ink", "ghostty:assign")
    # Rendering levers that serve the paper feel rather than the palette.
    # font-thicken emulates ink bleed; a blinking cursor is the one thing no
    # electrophoretic panel can do.
    splice(CFG / "ghostty/config.ghostty",
           "font-thicken = true\ncursor-style-blink = false",
           "ghostty:render")

# --------------------------------------------------------------------------
# Yazi
#
# Full-invert chips (white on ink) are kept ONLY for the mode indicator and
# the hovered row: in a file manager the cursor position is the single most
# important thing on screen, and those two are small and low-frequency.
# Everything else that used to invert now fills.
# --------------------------------------------------------------------------

def emit_yazi():
    t = f'''# e-ink for Yazi. {BANNER}

[mgr]
cwd = {{ fg = "{ink}", bold = true }}
find_keyword = {{ fg = "{ink}", bg = "{selection}", bold = true }}
find_position = {{ fg = "{slate}", bg = "{highlight}" }}
symlink_target = {{ fg = "{slate}", italic = true }}
marker_copied = {{ fg = "{paper}", bg = "{slate}", bold = true }}
marker_cut = {{ fg = "{paper}", bg = "{charcoal}", bold = true }}
marker_marked = {{ fg = "{ink}", bg = "{selection}", bold = true }}
marker_selected = {{ fg = "{paper}", bg = "{ink}", bold = true }}
count_copied = {{ fg = "{paper}", bg = "{slate}", bold = true }}
count_cut = {{ fg = "{paper}", bg = "{charcoal}", bold = true }}
count_selected = {{ fg = "{paper}", bg = "{ink}", bold = true }}
border_symbol = "│"
border_style = {{ fg = "{rule}" }}

[indicator]
parent = {{ reversed = true, bold = true }}
current = {{ reversed = true, bold = true }}
preview = {{ fg = "{muted}" }}
padding = {{ open = "▐", close = "▌" }}

[tabs]
active = {{ fg = "{paper}", bg = "{ink}", bold = true }}
inactive = {{ fg = "{slate}", bg = "{highlight}" }}
sep_inner = {{ open = " ", close = " " }}
sep_outer = {{ open = "", close = "" }}

[mode]
normal_main = {{ fg = "{paper}", bg = "{ink}", bold = true }}
normal_alt = {{ fg = "{slate}", bg = "{highlight}" }}
select_main = {{ fg = "{paper}", bg = "{charcoal}", bold = true }}
select_alt = {{ fg = "{slate}", bg = "{highlight}" }}
unset_main = {{ fg = "{paper}", bg = "{slate}", bold = true }}
unset_alt = {{ fg = "{slate}", bg = "{highlight}" }}

[status]
overall = {{ fg = "{charcoal}", bg = "{cursorline}" }}
sep_left = {{ open = "", close = " " }}
sep_right = {{ open = " ", close = "" }}
perm_type = {{ fg = "{slate}" }}
perm_read = {{ fg = "{charcoal}" }}
perm_write = {{ fg = "{slate}" }}
perm_exec = {{ fg = "{ink}", bold = true }}
perm_sep = {{ fg = "{rule}" }}
progress_label = {{ fg = "{ink}", bold = true }}
progress_normal = {{ fg = "{slate}", bg = "{selection}" }}
progress_error = {{ fg = "{ERROR}", bg = "{selection}", bold = true }}

[which]
cols = 2
mask = {{ fg = "{muted}" }}
cand = {{ fg = "{ink}", bold = true }}
rest = {{ fg = "{slate}" }}
desc = {{ fg = "{charcoal}" }}
separator = " → "
separator_style = {{ fg = "{rule}" }}

[confirm]
border = {{ fg = "{rule}" }}
title = {{ fg = "{ink}", bold = true }}
body = {{ fg = "{charcoal}" }}
list = {{ fg = "{slate}" }}
btn_yes = {{ fg = "{paper}", bg = "{ink}", bold = true }}
btn_no = {{ fg = "{ink}", bg = "{selection}" }}
btn_labels = [ "Yes", "No" ]

[spot]
border = {{ fg = "{rule}" }}
title = {{ fg = "{ink}", bold = true }}
tbl_col = {{ fg = "{ink}", bg = "{selection}", bold = true }}
tbl_cell = {{ fg = "{charcoal}", bg = "{cursorline}" }}

[notify]
title_info = {{ fg = "{ink}", bold = true }}
title_warn = {{ fg = "{WARNING}", bold = true }}
title_error = {{ fg = "{ERROR}", bold = true, underline = true }}

[pick]
border = {{ fg = "{rule}" }}
active = {{ fg = "{ink}", bg = "{highlight}", bold = true }}
inactive = {{ fg = "{charcoal}" }}

[input]
border = {{ fg = "{rule}" }}
title = {{ fg = "{ink}", bold = true }}
value = {{ fg = "{charcoal}" }}
selected = {{ fg = "{ink}", bg = "{selection}", bold = true }}

[cmp]
border = {{ fg = "{rule}" }}
active = {{ fg = "{ink}", bg = "{highlight}", bold = true }}
inactive = {{ fg = "{charcoal}" }}

[tasks]
border = {{ fg = "{rule}" }}
title = {{ fg = "{ink}", bold = true }}
hovered = {{ fg = "{ink}", bg = "{highlight}", bold = true }}

[help]
on = {{ fg = "{ink}", bold = true }}
run = {{ fg = "{charcoal}" }}
desc = {{ fg = "{slate}" }}
hovered = {{ fg = "{ink}", bg = "{highlight}", bold = true }}
footer = {{ fg = "{slate}", italic = true }}
icon_info = "i"
icon_warn = "!"
icon_error = "×"

[filetype]
rules = [
    {{ url = "*/", fg = "{ink}", bold = true }},
    {{ url = "*", fg = "{charcoal}" }},
]

# Neutral glyphs instead of coloured devicons -- a panel has no hues to spend.
[icon]
globs = []
dirs = []
files = []
exts = []
conds = [
    {{ if = "orphan", text = "", fg = "{muted}" }},
    {{ if = "link", text = "", fg = "{slate}" }},
    {{ if = "hidden & dir", text = "", fg = "{charcoal}" }},
    {{ if = "dir", text = "", fg = "{ink}" }},
    {{ if = "exec", text = "󰆍", fg = "{ink}" }},
    {{ if = "block | char | fifo | sock", text = "󰜫", fg = "{slate}" }},
    {{ if = "!(dir | link)", text = "󰈔", fg = "{charcoal}" }},
]
'''
    write(CFG / "yazi/theme-eink.toml", t, "yazi")
    write(CFG / "yazi/theme.toml", t, "yazi:assign")

# --------------------------------------------------------------------------
# btop
#
# Gradients run light -> dark, so a busier meter is a heavier mark. Only the
# temperature gradient is allowed to end in the error accent, because that is
# the one reading on the screen that means something is wrong.
# --------------------------------------------------------------------------

def emit_btop():
    L = RAMP
    kv = {
        "main_bg": paper, "main_fg": charcoal, "title": ink, "hi_fg": ink,
        "selected_bg": highlight, "selected_fg": ink, "inactive_fg": faint,
        "graph_text": muted, "meter_bg": highlight, "proc_misc": slate,
        "cpu_box": rule, "mem_box": rule, "net_box": rule, "proc_box": rule,
        "div_line": rule,
        "temp_start": L[11], "temp_mid": slate, "temp_end": ERROR,
        "cpu_start": L[11], "cpu_mid": slate, "cpu_end": ink,
        "free_start": L[12], "free_mid": L[9], "free_end": slate,
        "cached_start": L[11], "cached_mid": L[7], "cached_end": slate,
        "available_start": L[12], "available_mid": L[9], "available_end": slate,
        "used_start": L[10], "used_mid": charcoal, "used_end": ink,
        "download_start": L[11], "download_mid": slate, "download_end": ink,
        "upload_start": L[11], "upload_mid": slate, "upload_end": ink,
        "process_start": L[11], "process_mid": slate, "process_end": ink,
        "proc_banner_bg": paper, "proc_banner_fg": ink,
        "followed_bg": highlight, "followed_fg": ink,
        "proc_follow_bg": highlight, "proc_pause_bg": selection,
    }
    body = "\n".join(f'theme[{k}]="{v}"' for k, v in kv.items())
    write(CFG / "btop/themes/eink.theme",
          f"# e-ink for btop. {BANNER}\n"
          f"# Gradients run light -> dark; only temp_end reaches for the error accent.\n\n"
          + body, "btop")
    set_key(CFG / "btop/btop.conf", r'^color_theme\s*=\s*".*"',
            'color_theme = "eink"', "btop:assign")

# --------------------------------------------------------------------------
# mako / niri / jay -- the desktop surfaces
# --------------------------------------------------------------------------

def emit_mako():
    # The three colour keys already exist at the top of the file, so they are
    # rewritten in place. Appending them instead would leave the originals
    # sitting above ours as dead values that merely lose a last-wins contest.
    p = CFG / "mako/config"
    set_key(p, r'^background-color=.*$', f"background-color={paper}", "mako:bg")
    set_key(p, r'^text-color=.*$',       f"text-color={ink}",         "mako:fg")
    set_key(p, r'^border-color=.*$',     f"border-color={rule}",      "mako:border")
    splice(p, f"""border-size=1
progress-color=over {highlight}

[urgency=low]
text-color={slate}
border-color={rule}

[urgency=high]
text-color={ink}
border-color={ERROR}
border-size=2""", "mako:urgency")

# --------------------------------------------------------------------------
# niri window-open / window-close shader
#
# Adapted from arch-disciple/niri-shader-collection, 10_Advanced/burn.kdl.
# Three things had to change before it belonged on this palette:
#
#   * X IS ASPECT-CORRECTED. coords_geo arrives normalised 0..1 over the
#     window geometry -- measured, not assumed: a checkerboard of
#     `coords_geo * 8.0` renders as exactly 8 cells across the window on niri
#     26.04. So upstream's raw coords_geo.xy is the right frequency and is
#     kept. Do NOT divide by size_geo: that collapses the noise field to one
#     constant and the whole window flips at a single instant instead of
#     burning. Only x is scaled, by the aspect ratio, so the lobes stay round
#     on a wide column instead of stretching into bands.
#
#   * THE FRONT DARKENS INSTEAD OF GLOWING. Upstream adds a doubled fire
#     colour on top, which is the correct move on a dark desktop and invisible
#     here: every window on this machine is already near paper white, so
#     anything added clips to white and the burn edge disappears. Paper
#     charring, seen against a lit sheet, reads as DARKENING -- so the front is
#     a mix toward the ramp, never a glow over it.
#
#   * NO ACCENT. This is an ash dissolve, not a fire: it burns on the ramp
#     alone, so it reads by VALUE the way the rest of the system does. error
#     and warning stay reserved for the one job eink.toml keeps them for.
#     Value is the only cue left, so it needs two stops rather than one: a wide
#     slate haze ahead of the front, then a hard ink rim at the very edge. The
#     rim is what makes it read as burnt paper instead of a window fading out,
#     and at 500ms it is the only part that has time to register.
#
# The front sweeps from -0.25 to 1.05, i.e. past both ends of the noise range,
# so the window starts wholly unburnt and ends wholly gone. Stopping at 0 and 1
# would leave a pre-scorched frame at the start and permanent holes at the end.
# --------------------------------------------------------------------------

def glsl_rgb(hexstr):
    """#rrggbb -> a GLSL vec3 literal, so palette colours can reach shaders."""
    r, g, b = (int(hexstr[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return f"vec3({r:.4f}, {g:.4f}, {b:.4f})"

# Which window animation is live: "ink-splash" or "burn". Both templates are
# kept here so the block has one source of truth and switching is this one line.
# burn draws from the ramp; ink-splash carries no colour at all -- it only ever
# multiplies the window's own pixels, which is why it needs no palette and
# cannot drift when the ramp moves.
NIRI_ANIMATION = "ink-splash"

# Ported unmodified from liixini/shaders (ink-splash). It needed no adaptation:
# it writes no colour, and it already reads coords_geo as normalised 0..1 and
# aspect-corrects x off size_geo -- the same conventions the burn had to be
# corrected to. Durations sit above the repo README's 400-800ms band because
# the reveal completes at about p=0.74 (boundary = p * 1.7 - 0.15 outruns the
# largest distorted radius), so the tail of each is idle.
INK_SPLASH_OPEN = '''
            // Ported from skwd-wall ink-splash transition

            float is_hash(vec2 p) {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
            }

            float is_noise(vec2 p) {
                vec2 i = floor(p);
                vec2 f = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                return mix(mix(is_hash(i), is_hash(i + vec2(1.0, 0.0)), f.x),
                           mix(is_hash(i + vec2(0.0, 1.0)), is_hash(i + vec2(1.0, 1.0)), f.x), f.y);
            }

            float is_fbm(vec2 p) {
                float v = 0.0;
                float amp = 0.5;
                for (int i = 0; i < 4; i++) {
                    v += amp * is_noise(p);
                    p *= 2.1;
                    amp *= 0.5;
                }
                return v;
            }

            vec4 open_color(vec3 coords_geo, vec3 size_geo) {
                float p = niri_clamped_progress;
                vec2 uv = coords_geo.xy;
                vec3 tc = niri_geo_to_tex * vec3(uv, 1.0);
                vec4 win = texture2D(niri_tex, tc.st);

                float blob = is_fbm(uv * 3.5);
                float fingers = is_fbm(uv * 14.0);
                float distortion = (blob - 0.5) * 0.5 + (fingers - 0.5) * 0.18;
                vec2 c = uv - vec2(0.5);
                c.x *= size_geo.x / max(size_geo.y, 0.0001);
                float d = length(c);
                float splash_d = d + distortion;
                float boundary = p * 1.7 - 0.15;
                float diff = splash_d - boundary;
                float reveal = smoothstep(0.04, -0.04, diff);

                return win * reveal;
            }
'''

INK_SPLASH_CLOSE = '''
            // Ported from skwd-wall ink-splash transition

            float is_hash(vec2 p) {
                return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
            }

            float is_noise(vec2 p) {
                vec2 i = floor(p);
                vec2 f = fract(p);
                f = f * f * (3.0 - 2.0 * f);
                return mix(mix(is_hash(i), is_hash(i + vec2(1.0, 0.0)), f.x),
                           mix(is_hash(i + vec2(0.0, 1.0)), is_hash(i + vec2(1.0, 1.0)), f.x), f.y);
            }

            float is_fbm(vec2 p) {
                float v = 0.0;
                float amp = 0.5;
                for (int i = 0; i < 4; i++) {
                    v += amp * is_noise(p);
                    p *= 2.1;
                    amp *= 0.5;
                }
                return v;
            }

            vec4 close_color(vec3 coords_geo, vec3 size_geo) {
                float p = 1.0 - niri_clamped_progress;
                vec2 uv = coords_geo.xy;
                vec3 tc = niri_geo_to_tex * vec3(uv, 1.0);
                vec4 win = texture2D(niri_tex, tc.st);

                float blob = is_fbm(uv * 3.5);
                float fingers = is_fbm(uv * 14.0);
                float distortion = (blob - 0.5) * 0.5 + (fingers - 0.5) * 0.18;
                vec2 c = uv - vec2(0.5);
                c.x *= size_geo.x / max(size_geo.y, 0.0001);
                float d = length(c);
                float splash_d = d + distortion;
                float boundary = p * 1.7 - 0.15;
                float diff = splash_d - boundary;
                float reveal = smoothstep(0.04, -0.04, diff);

                return win * reveal;
            }
'''

NIRI_BURN = '''
      float hash(vec2 p) {
          return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
      }

      float noise(vec2 p) {
          vec2 i = floor(p);
          vec2 f = fract(p);
          f = f * f * (3.0 - 2.0 * f);
          return mix(mix(hash(i),                  hash(i + vec2(1.0, 0.0)), f.x),
                     mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
      }

      float fbm(vec2 p) {
          float total = 0.0;
          float amplitude = 0.5;
          // Constant loop bound: GLSL ES 1.00 only promises loops it can unroll.
          for (int i = 0; i < 5; i++) {
              total += noise(p) * amplitude;
              p *= 2.0;
              amplitude *= 0.5;
          }
          return total;
      }

      vec4 burn(vec3 coords_geo, vec3 size_geo, float front) {
          // Already 0..1 over the window. size_geo is only consulted for
          // the aspect ratio.
          vec2 coords = coords_geo.xy;
          coords.x *= size_geo.x / size_geo.y;

          float lobes  = 3.0 + niri_random_seed * 5.0;
          float offset = 25.0 + niri_random_seed * 100.0;

          // fbm lands well inside 0..1. Stretched, so the front sweeps the
          // whole window over the whole duration instead of stalling at both
          // ends of the animation.
          float n = clamp((fbm(coords * lobes + offset) - 0.2) / 0.6, 0.0, 1.0);

          // Signed distance to the burn front. Positive is not alight yet.
          float d = n - front;

          float alive = smoothstep(0.0,  0.02, d);
          float rim   = smoothstep(0.10, 0.03, d);
          float haze  = smoothstep(0.24, 0.06, d);

          vec3 coords_tex = niri_geo_to_tex * coords_geo;
          vec4 color = texture2D(niri_tex, coords_tex.st);

          // Premultiplied alpha throughout: every colour written is scaled by
          // color.a, so transparent corners stay transparent rather than
          // catching fire on their own.
          color.rgb = mix(color.rgb, @HAZE@ * color.a, haze * 0.85);
          color.rgb = mix(color.rgb, @CHAR@ * color.a, rim);

          return color * alive;
      }

      vec4 @FN@(vec3 coords_geo, vec3 size_geo) {
          return burn(coords_geo, size_geo, mix(@FROM@, @TO@, niri_clamped_progress));
      }
'''

def niri_shader(which):
    """The GLSL for one direction, per NIRI_ANIMATION."""
    if NIRI_ANIMATION == "burn":
        return (niri_burn("open_color", "1.05", "-0.25") if which == "open"
                else niri_burn("close_color", "-0.25", "1.05"))
    return (INK_SPLASH_OPEN if which == "open" else INK_SPLASH_CLOSE).rstrip()

# linear, deliberately: an ink blot spreads at a roughly constant rate, and an
# eased curve front-loads the progress so hard that the reveal -- which is
# already complete at about p=0.74 -- is over in the first third of the
# duration. Durations are trimmed to compensate for that same early finish.
NIRI_DURATIONS = {"burn": (500, "ease-out-quad", 400, "linear"),
                  "ink-splash": (700, "linear", 550, "linear")}

def niri_burn(fn, frm, to):
    return (NIRI_BURN
            .replace("@FN@", fn).replace("@FROM@", frm).replace("@TO@", to)
            .replace("@CHAR@", glsl_rgb(ink))
            .replace("@HAZE@", glsl_rgb(slate)).rstrip())

def emit_niri():
    # Patched key-by-key: KDL blocks are hand-arranged and a spliced region
    # would land outside the layout{} scope it has to live in.
    p = CFG / "niri/config.kdl"
    set_key(p, r'^(\s*)active-color\s+".*"',   rf'\1active-color "{ink}"',      "niri:active")
    set_key(p, r'^(\s*)inactive-color\s+".*"', rf'\1inactive-color "{rule}"',   "niri:inactive")
    set_key(p, r'^(\s*)urgent-color\s+".*"',   rf'\1urgent-color "{ERROR}"',    "niri:urgent")
    set_key(p, r'^(\s*)backdrop-color\s+".*"', rf'\1backdrop-color "{highlight}"', "niri:backdrop")

    # The animations themselves ARE the theme, so they are spliced whole into
    # the sentinels sitting inside the hand-written animations{} node. That
    # keeps one animations block in the file: a second top-level one would
    # quietly win over the first.
    od, oc, cd, cc = NIRI_DURATIONS[NIRI_ANIMATION]
    splice(p, f"""// Window open / close: {NIRI_ANIMATION}. {BANNER}
    window-open {{
        duration-ms {od}
        curve "{oc}"
        custom-shader r"{niri_shader("open")}
        "
    }}

    window-close {{
        duration-ms {cd}
        curve "{cc}"
        custom-shader r"{niri_shader("close")}
        "
    }}""", "niri:anim", comment="//")

def emit_jay():
    p = CFG / "jay/config.toml"
    for key, val, label in (
        ("bg-color", highlight, "bg"), ("bar-bg-color", paper, "bar"),
        ("border-color", rule, "border"), ("separator-color", rule, "sep"),
        ("unfocused-title-bg-color", cursorline, "utbg"),
        ("unfocused-title-text-color", muted, "uttx"),
        ("focused-title-bg-color", highlight, "ftbg"),
        ("focused-title-text-color", ink, "fttx"),
    ):
        set_key(p, rf'^{re.escape(key)}\s*=\s*".*"', f'{key} = "{val}"', f"jay:{label}")

# --------------------------------------------------------------------------
# hunk
#
# Schema taken from the shipped type declarations
# (hunkdiff/dist/npm/extension/extension-api/types.d.ts, CustomThemeConfig).
# `base` supplies sane values for any slot left unset.
#
# Added and removed cannot be green and red here, so they separate by FILL
# WEIGHT instead: added sits two ramp levels lighter than removed, and the
# sign column carries ink vs slate on top of that.
# --------------------------------------------------------------------------

def emit_hunk():
    L = RAMP
    scopes = {
        "comment": muted, "string": charcoal, "keyword": ink,
        "entity.name.function": ink, "entity.name.type": ink,
        "constant.numeric": charcoal, "constant.language": charcoal,
        "variable": ink, "variable.parameter": charcoal,
        "punctuation": slate, "keyword.operator": charcoal, "invalid": ERROR,
    }
    body = f'''[themes.eink]
base = "github-light"
label = "E-Ink"
background = "{paper}"
panel = "{paper}"
panelAlt = "{cursorline}"
border = "{rule}"
accent = "{ink}"
accentMuted = "{slate}"
text = "{ink}"
muted = "{muted}"
addedBg = "{L[14]}"
removedBg = "{L[12]}"
movedAddedBg = "{L[13]}"
movedRemovedBg = "{L[11]}"
contextBg = "{paper}"
addedContentBg = "{L[13]}"
removedContentBg = "{L[11]}"
contextContentBg = "{paper}"
addedSignColor = "{ink}"
removedSignColor = "{slate}"
lineNumberBg = "{paper}"
lineNumberFg = "{faint}"
selectedHunk = "{highlight}"
badgeAdded = "{ink}"
badgeRemoved = "{slate}"
badgeNeutral = "{muted}"
fileNew = "{ink}"
fileDeleted = "{slate}"
fileRenamed = "{charcoal}"
fileModified = "{ink}"
fileUntracked = "{muted}"
noteBorder = "{rule}"
noteBackground = "{cursorline}"
noteTitleBackground = "{highlight}"
noteTitleText = "{ink}"

[themes.eink.syntaxScopes]
''' + "\n".join(f'"{k}" = "{v}"' for k, v in scopes.items())
    splice(CFG / "hunk/config.toml", body, "hunk")
    set_key(CFG / "hunk/config.toml", r'^theme\s*=\s*".*"', 'theme = "eink"', "hunk:assign")

# --------------------------------------------------------------------------
# lazygit
# --------------------------------------------------------------------------

def emit_lazygit():
    write(CFG / "lazygit/config.yml", f"""# e-ink for lazygit. {BANNER}
gui:
  theme:
    activeBorderColor:
      - "{ink}"
      - bold
    inactiveBorderColor:
      - "{rule}"
    searchingActiveBorderColor:
      - "{ink}"
      - bold
    optionsTextColor:
      - "{muted}"
    selectedLineBgColor:
      - "{highlight}"
    inactiveViewSelectedLineBgColor:
      - "{cursorline}"
    cherryPickedCommitFgColor:
      - "{paper}"
    cherryPickedCommitBgColor:
      - "{charcoal}"
    markedBaseCommitFgColor:
      - "{paper}"
    markedBaseCommitBgColor:
      - "{slate}"
    unstagedChangesColor:
      - "{ERROR}"
    defaultFgColor:
      - "{ink}"
""", "lazygit")

# --------------------------------------------------------------------------
# spotify-player
#
# Schema read out of the binary's own string table: ThemeConfig -> Palette /
# ComponentStyle. Component styles address the palette by ratatui colour NAME,
# so the hex values live in [themes.palette] and are referenced symbolically.
# --------------------------------------------------------------------------

def emit_spotify():
    write(CFG / "spotify-player/theme.toml", f'''# e-ink for spotify-player. {BANNER}

[[themes]]
name = "eink"

[themes.palette]
background = "{paper}"
foreground = "{ink}"
black = "{ink}"
red = "{ERROR}"
green = "{charcoal}"
yellow = "{WARNING}"
blue = "{slate}"
magenta = "{charcoal}"
cyan = "{slate}"
white = "{rule}"
bright_black = "{muted}"
bright_red = "{ERROR}"
bright_green = "{ink}"
bright_yellow = "{WARNING}"
bright_blue = "{ink}"
bright_magenta = "{slate}"
bright_cyan = "{muted}"
bright_white = "{ink}"

[themes.component_style]
block_title = {{ fg = "Black" }}
border = {{ fg = "White" }}
playback_status = {{ fg = "Black" }}
playback_track = {{ fg = "Black" }}
playback_album = {{ fg = "Magenta" }}
playback_genres = {{ fg = "Blue" }}
playback_metadata = {{ fg = "BrightBlack" }}
playback_progress_bar = {{ bg = "BrightBlack", fg = "Black" }}
playback_progress_bar_unfilled = {{ bg = "White", fg = "BrightBlack" }}
current_playing = {{ fg = "Black", modifiers = ["Italic"] }}
page_desc = {{ fg = "Black" }}
playlist_desc = {{ fg = "BrightBlack" }}
table_header = {{ fg = "Blue" }}
selection = {{ fg = "Black", modifiers = ["Underlined"] }}
secondary_row = {{ bg = "White" }}
lyrics_played = {{ fg = "BrightBlack" }}
lyrics_playing = {{ fg = "Black", modifiers = ["Italic"] }}
''', "spotify")
    set_key(CFG / "spotify-player/app.toml", r'^theme\s*=\s*".*"',
            'theme = "eink"', "spotify:assign")

# --------------------------------------------------------------------------
# glow  (glamour JSON stylesheet)
#
# glamour silently ignores keys it does not recognise, so anything misspelled
# here fails invisibly rather than loudly. Keys kept to the documented set.
# --------------------------------------------------------------------------

def emit_glow():
    import json
    def prim(**kw): return kw
    style = {
        "document": {"block_prefix": "\n", "block_suffix": "\n", "margin": 2, "color": ink},
        "block_quote": {"color": slate, "italic": True, "indent": 1, "indent_token": "| "},
        "paragraph": {},
        "list": {"level_indent": 2, "color": ink},
        "heading": {"block_suffix": "\n", "color": ink, "bold": True},
        "h1": {"prefix": "", "suffix": "", "color": ink, "bold": True, "underline": True},
        "h2": {"prefix": "## ", "color": ink, "bold": True},
        "h3": {"prefix": "### ", "color": charcoal, "bold": True},
        "h4": {"prefix": "#### ", "color": charcoal, "bold": True, "italic": True},
        "h5": {"prefix": "##### ", "color": slate, "bold": True},
        "h6": {"prefix": "###### ", "color": slate, "italic": True},
        "strikethrough": {"crossed_out": True, "color": muted},
        "emph": {"italic": True, "color": charcoal},
        "strong": {"bold": True, "color": ink},
        "hr": {"color": rule, "format": "\n--------\n"},
        "item": {"block_prefix": "- "},
        "enumeration": {"block_prefix": ". "},
        "task": {"ticked": "[x] ", "unticked": "[ ] "},
        "link": {"color": charcoal, "underline": True},
        "link_text": {"color": ink, "bold": True},
        "image": {"color": slate, "underline": True},
        "image_text": {"color": slate, "format": "Image: {{.text}}"},
        "code": {"color": charcoal},
        "code_block": {
            "margin": 2, "color": charcoal,
            "chroma": {
                "text": {"color": ink}, "error": {"color": ERROR},
                "comment": {"color": muted, "italic": True},
                "comment_preproc": {"color": charcoal, "bold": True},
                "keyword": {"color": ink, "bold": True},
                "keyword_reserved": {"color": ink, "bold": True},
                "keyword_namespace": {"color": charcoal, "bold": True},
                "keyword_type": {"color": ink, "bold": True},
                "operator": {"color": charcoal, "bold": True},
                "punctuation": {"color": slate},
                "name": {"color": ink},
                "name_builtin": {"color": charcoal, "italic": True},
                "name_tag": {"color": ink, "bold": True},
                "name_attribute": {"color": charcoal, "italic": True},
                "name_class": {"color": ink, "bold": True},
                "name_constant": {"color": charcoal, "bold": True},
                "name_decorator": {"color": charcoal, "italic": True},
                "name_exception": {"color": ERROR},
                "name_function": {"color": ink, "bold": True},
                "name_other": {"color": ink},
                "literal": {"color": charcoal},
                "literal_number": {"color": charcoal},
                "literal_string": {"color": charcoal},
                "literal_string_escape": {"color": ink, "bold": True},
                "generic_deleted": {"color": slate, "crossed_out": True},
                "generic_inserted": {"color": ink, "underline": True},
                "generic_emph": {"italic": True, "color": charcoal},
                "generic_strong": {"bold": True, "color": ink},
                "generic_subheading": {"color": slate},
                "background": {"background_color": paper},
            },
        },
        "table": {"center_separator": "+", "column_separator": "|", "row_separator": "-"},
        "definition_term": {"color": ink, "bold": True},
        "definition_description": {"color": charcoal, "block_prefix": "\n  "},
        "html_block": {"color": muted},
        "html_span": {"color": muted},
        "text": {"color": ink},
    }
    write(CFG / "glow/eink.json", json.dumps(style, indent=2), "glow")
    set_key(CFG / "glow/glow.yml", r'^style:\s*".*"',
            f'style: "{Path.home()}/.config/glow/eink.json"', "glow:assign")

# --------------------------------------------------------------------------
# fish
#
# conf.d rather than universal variables: `set -g` here loses to any
# fish_color_* uvar, and this machine has none set, so nothing is shadowed and
# nothing is written into fish_variables that would outlive the theme.
# --------------------------------------------------------------------------

def emit_fish():
    n = lambda c: c.lstrip("#")
    write(CFG / "fish/conf.d/eink-theme.fish", f"""# e-ink for fish. {BANNER}
# Remove this file to return fish to its defaults; nothing else is touched.

set -g fish_color_normal {n(ink)}
set -g fish_color_command {n(ink)} --bold
set -g fish_color_keyword {n(ink)} --bold
set -g fish_color_quote {n(charcoal)}
set -g fish_color_redirection {n(slate)}
set -g fish_color_end {n(slate)}
set -g fish_color_error {n(ERROR)} --bold
set -g fish_color_param {n(charcoal)}
set -g fish_color_option {n(charcoal)}
set -g fish_color_comment {n(muted)} --italics
set -g fish_color_selection {n(ink)} --background={n(selection)}
set -g fish_color_operator {n(charcoal)}
set -g fish_color_escape {n(ink)} --bold
set -g fish_color_autosuggestion {n(faint)}
set -g fish_color_cwd {n(ink)} --bold
set -g fish_color_user {n(charcoal)}
set -g fish_color_host {n(charcoal)}
set -g fish_color_host_remote {n(WARNING)}
set -g fish_color_cancel {n(muted)}
set -g fish_color_valid_path --underline
set -g fish_color_search_match --background={n(highlight)}
set -g fish_color_history_current --bold

set -g fish_pager_color_progress {n(muted)}
set -g fish_pager_color_prefix {n(ink)} --bold
set -g fish_pager_color_completion {n(charcoal)}
set -g fish_pager_color_description {n(muted)} --italics
set -g fish_pager_color_selected_background --background={n(highlight)}
set -g fish_pager_color_selected_completion {n(ink)} --bold
""", "fish")

# --------------------------------------------------------------------------
# glide
#
# Kept in its own module so styles.glide.ts stays hand-written. Disable by
# deleting the glide.include line this adds to glide.ts.
#
# NOTE: this is the one surface that could not be verified without launching
# the browser. The chrome it repaints was dark, so both background AND text
# colour are set together -- a background-only change would leave light text
# on light paper.
# --------------------------------------------------------------------------

def emit_glide():
    """
    Variables and selectors taken from Glide's own chrome CSS, read out of
    /opt/glide-browser-bin/omni.ja:
        chrome/toolkit/skin/classic/global/glide.css              (defaults)
        chrome/toolkit/skin/classic/global/glide-commandline.css  (selectors)

    Two classes of fix are needed and neither is optional.

    1. Variables. Glide re-declares most of these inside a
       `@media (prefers-color-scheme: dark)` block, so every override needs
       !important or the dark value wins.

    2. Hardcoded colours. Several rules in glide-commandline.css do not read a
       variable at all -- the URL grey, the hover fill, and two hairline
       borders are literals. Worse, the hover fill and both borders are white
       at low alpha: designed for a dark panel, they vanish completely on
       paper. Those need selector-level rules, not variable overrides.
    """
    L = RAMP
    content = f"""/**
 * e-ink browser chrome. {BANNER}
 *
 * Loaded after styles.glide.ts so it wins on the surfaces both touch.
 */

glide.styles.add(
  css`
    :root {{
      /* Generic ------------------------------------------------------- */
      --glide-bg: {paper} !important;
      --glide-fg: {ink} !important;

      /* Commandline input row ----------------------------------------- */
      --glide-cmdl-bg: {paper} !important;
      --glide-cmdl-fg: {ink} !important;

      /* Completion list ----------------------------------------------- */
      --glide-cmplt-bg: {paper} !important;
      --glide-cmplt-fg: {ink} !important;
      --glide-cmplt-border-top: 1px solid {rule} !important;

      /* Section headers. These default to #111 -- a black slab across the
         top of the sheet, and the reason this file exists. */
      --glide-header-first-bg: {cursorline} !important;
      --glide-header-second-bg: {highlight} !important;
      --glide-header-third-bg: {selection} !important;
      --glide-header-border-bottom: 1px solid {rule} !important;

      /* Focused option. Glide inverts to #fff, which on paper is very
         nearly invisible; a fill reads correctly and matches every other
         selected row in the system. */
      --glide-of-bg: {highlight} !important;
      --glide-of-fg: {ink} !important;

      /* URLs. Default is a saturated green in both schemes. */
      --glide-url-fg: {slate} !important;
      --glide-url-bg: transparent !important;
      --glide-url-text-decoration: none !important;

      /* Mode indicator. The defaults are seven saturated hues; here each
         mode gets its own step on the ramp, so they separate by value the
         way the rest of the system does. */
      --glide-status-bg: {paper} !important;
      --glide-status-fg: {ink} !important;
      --glide-status-border: 1px solid {rule} !important;
      --glide-mode-normal: {L[0]} !important;
      --glide-mode-insert: {L[2]} !important;
      --glide-mode-visual: {L[4]} !important;
      --glide-mode-command: {L[6]} !important;
      --glide-mode-hint: {L[5]} !important;
      --glide-mode-op-pending: {L[8]} !important;
      --glide-mode-ignore: {L[9]} !important;
      --glide-fallback-mode: {paper} !important;

      /* Search + link hints. The hint tag keeps a full invert on purpose:
         it is the one element that must be unmissable, exactly as the jump
         label does in the editor. */
      --glide-search-highlight-color: {selection} !important;
      --glide-hintspan-fg: {paper} !important;
      --glide-hintspan-bg: {ink} !important;
      --glide-hintspan-border-color: {rule} !important;
      --glide-hint-active-fg: {ink} !important;
      --glide-hint-active-bg: {highlight} !important;
      --glide-hint-active-outline: 1px solid {ink} !important;
      --glide-hint-bg: {cursorline} !important;
      --glide-hint-outline: 1px solid {rule} !important;
      --glide-hint-color: {ink} !important;
      --glide-hint-border: solid 1px {rule} !important;
      --glide-hint-background: {highlight} !important;

      /* Scrollbar + the JS-link hint tint: both default to raw greys that
         sit off the ramp. */
      --glide-scrollbar-color: {muted} {cursorline} !important;
      --glide-hintspan-js-background: {slate} !important;

      /* :viewsource and the new-tab spoiler box */
      --glide-vs-bg: {paper} !important;
      --glide-vs-fg: {ink} !important;
      --glide-highlight-box-bg: {cursorline} !important;
      --glide-highlight-box-fg: {ink} !important;

      /* Berkeley Mono is not installed on this machine, so the commandline
         was falling back to an arbitrary monospace. Match the terminal. */
      --glide-cmdl-font-family: "GeistMono Nerd Font Mono", monospace !important;
      --glide-cmplt-font-family: "GeistMono Nerd Font Mono", monospace !important;
    }}

    /* ---- Rules that read no variable at all ------------------------- */

    /* White-at-low-alpha borders: invisible on paper. */
    [anonid="glide-commandline-holder"] {{
      border-top: 1px solid {rule} !important;
    }}

    /* Hover was hsla(0,0%,100%,0.05) -- a white wash over white. */
    [anonid="glide-commandline-completions"] .gcl-option:not(.focused):hover {{
      background: {cursorline} !important;
    }}

    /* URL and tab-group greys are hardcoded to a pale blue-grey literal,
       which lands near 2.4:1 on this paper. Both move onto the ramp. */
    .gcl-option:not(.focused) .url,
    [anonid="glide-commandline-completions"] table tr td.tgroup {{
      color: {muted} !important;
    }}

    /* The prefix column carries bookmark/history markers. Setting color
       covers a text glyph; the grayscale filter covers the emoji case,
       where the glyph paints itself and ignores color entirely. */
    [anonid="glide-commandline-completions"] table tr td.prefix {{
      color: {slate} !important;
      filter: grayscale(1) !important;
    }}

    .FindCompletionOption .match {{
      color: {paper} !important;
      background: {ink} !important;
    }}

    /* Chrome surfaces. #nav-bar is collapsed by styles.glide.ts; these keep
       it correct if it is ever shown again. */
    :root {{
      --toolbar-bgcolor: {paper} !important;
    }}

    #navigator-toolbox,
    #nav-bar {{
      background-color: {paper} !important;
      background-image: none !important;
      color: {ink} !important;
    }}
  `,
  {{ id: "eink-chrome" }},
);
"""
    # A backtick anywhere inside the css`` template ends it early: JS tokenises
    # the literal long before any of it reaches the CSS parser, so the file
    # becomes a syntax error rather than a styling mistake. Prose in the CSS
    # comments is the easy way to introduce one.
    if content.count("`") != 2:
        raise SystemExit(
            f"glide: emitted {content.count('`')} backticks, expected exactly 2 "
            f"(one pair for the css template). A stray backtick -- usually in a "
            f"CSS comment -- would terminate the literal and break the config."
        )
    write(CFG / "glide/config/eink.glide.ts", content, "glide")
    splice(CFG / "glide/glide.ts",
           'glide.include("config/eink.glide.ts");', "glide:include", comment="//")

# --------------------------------------------------------------------------
# waybar
#
# Colour only. The bar's geometry lives in a hand-written style.css that
# @imports this file, so adding a module later never means editing generated
# output.
#
# Every state of the workspace pill reduces to one of the values below,
# because the marks are drawn as CSS circles rather than typeset as glyphs.
# That is not purity: there is no Font Awesome on this machine and no humanist
# face to set dots in, so a glyph would make the bar depend on a font that
# could be uninstalled -- and a mark drawn from background-color is a palette
# value the audit can actually see.
# --------------------------------------------------------------------------

def emit_waybar():
    names  = list(P["roles"]) + ["error", "warning"]
    values = {**R, "error": ERROR, "warning": WARNING}
    pad    = max(len(n) for n in names)
    body   = "\n".join(f"@define-color {n:<{pad}} {values[n]};" for n in names)
    write(CFG / "waybar/eink-colors.css", f"""/* {BANNER} */
/* GTK3 named colours for waybar, imported by style.css. That file holds the
   geometry, is hand-written, and is the one to edit. */

{body}
""", "waybar")

    # An undefined colour name is a GTK CSS parse error: waybar prints it to
    # stderr and then draws the bar unstyled, which is easy to miss when a bar
    # appears at all. Same reasoning as the backtick guard in emit_glide --
    # catch at build time what would otherwise surface as a styling mystery.
    style = CFG / "waybar/style.css"
    if style.exists():
        used = set(re.findall(r"@([A-Za-z_][\w-]*)", style.read_text()))
        stray = sorted(used - set(names) - {"import", "media", "define-color",
                                           "keyframes", "supports", "charset"})
        if stray:
            raise SystemExit(
                f"waybar: style.css refers to undefined colour(s) {stray}. "
                f"Defined here: {', '.join(names)}."
            )

# --------------------------------------------------------------------------

AUDIT_TARGETS = [
    "helix/themes/eink.toml", "ghostty/themes/E-Ink", "yazi/theme.toml",
    "btop/themes/eink.theme", "mako/config", "niri/config.kdl",
    "jay/config.toml", "hunk/config.toml", "lazygit/config.yml",
    "spotify-player/theme.toml", "glow/eink.json",
    "fish/conf.d/eink-theme.fish", "glide/config/eink.glide.ts",
    "waybar/eink-colors.css",
]

def audit():
    """Assert every colour on disk came from this palette. Shares RAMP above,
    so the audit can never disagree with the generator about what is legal."""
    allowed = set(RAMP) | {ERROR, WARNING}
    total = strays = 0
    for t in AUDIT_TARGETS:
        path = CFG / t
        if not path.exists():
            print(f"  MISSING {t}"); strays += 1; continue
        txt = path.read_text()
        found  = {h.lower() for h in re.findall(r"#[0-9a-fA-F]{6}\b", txt)}
        found |= {"#" + h.lower() for h in re.findall(r"^set -g \S+ ([0-9a-f]{6})", txt, re.M)}
        found |= {"#" + h.lower() for h in re.findall(r"--background=([0-9a-f]{6})", txt)}
        bad = sorted(found - allowed)
        total += len(found); strays += len(bad)
        print(f"  {'OK   ' if not bad else 'STRAY'} {t:<34} {len(found):>2}"
              + ("" if not bad else f"  {bad}"))
    print(f"\n  {total} colour references across {len(AUDIT_TARGETS)} files, "
          f"{strays} not from the ramp")
    print(f"  paper {RAMP[-1]}   ink {RAMP[0]}   range {contrast(RAMP[0], RAMP[-1]):.2f}:1")
    if strays:
        sys.exit(1)

def main():
    for fn in (emit_helix, emit_ghostty, emit_yazi, emit_btop, emit_mako,
               emit_niri, emit_jay, emit_hunk, emit_lazygit, emit_spotify,
               emit_glow, emit_fish, emit_glide, emit_waybar):
        fn()

    print(f"e-ink  |  ramp oklch(L {_r['l_min']}->{_r['l_max']}, C {_r['chroma']}, h {_r['hue']})"
          f"  |  ink/paper {contrast(ink, paper):.2f}:1")
    print("-" * 72)
    width = max(len(t) for _, t, _ in results)
    problems = 0
    for status, target, note in sorted(results, key=lambda r: r[1]):
        if status in ("MISSING", "NOKEY", "DRIFT"):
            problems += 1
        show = note.replace(str(Path.home()), "~")
        print(f"  {status:<9} {target:<{width}}  {show}")
    print("-" * 72)
    print(f"  {len(results)} targets, {problems} needing attention")
    if problems:
        sys.exit(1)

if __name__ == "__main__":
    audit() if "--audit" in sys.argv else main()
