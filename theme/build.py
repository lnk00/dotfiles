#!/usr/bin/env python3
"""
Render the e-ink palette into every themed surface on this machine.

    python3 ~/.config/theme/build.py            # build everything
    python3 ~/.config/theme/build.py --check    # report drift, write nothing

The palette lives in eink.toml next to this file and is the only thing meant
to be edited by hand. Every file this script writes carries a header saying so.

Two kinds of target:

  OWNED    the whole file belongs to the theme (helix, nvim, ghostty, yazi,
           btop, spotify, glow, fish). Written wholesale.
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

# ANSI 0-15, bound once and shared by every terminal-shaped surface: Ghostty
# and Neovim's :terminal. Red and yellow carry the two accents, so any CLI that
# prints an error or a warning lands on the same two colours the editor uses.
# Every other slot is a gray. Slot 7 stays light and 15 dark, matching the
# existing Monochrome Light convention on this machine.
ANSI = [ink, ERROR, charcoal, WARNING, slate, charcoal, slate, rule,
        muted, ERROR, ink, WARNING, ink, slate, muted, ink]

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

def set_toml_key(path: Path, section: str, key: str, val: str, label: str):
    """
    SHARED target, TOML flavour: rewrite `key = "..."` where it already exists,
    otherwise insert it at the end of [section]. set_key cannot be used for a
    key the user has never written -- it reports NOKEY and gives up, and
    appending the line instead would land it in whichever table happens to come
    last in the file rather than in the one it belongs to.
    """
    path = Path(path)
    if not path.exists():
        results.append(("MISSING", label, str(path)))
        return
    original = path.read_text()
    line = f'{key} = "{val}"'
    updated, n = re.subn(rf'^{re.escape(key)}\s*=\s*".*"$', line, original,
                         count=1, flags=re.M)
    inserted = False
    if n == 0:
        head = re.search(rf'^\[{re.escape(section)}\]\s*$', original, re.M)
        if not head:
            results.append(("NOKEY", label, f"{path}: no [{section}] table"))
            return
        nxt = re.search(r'^\[', original[head.end():], re.M)
        end = head.end() + (nxt.start() if nxt else len(original) - head.end())
        body = original[head.end():end].rstrip("\n")
        tail = original[end:]
        updated = (original[:head.end()] + body + "\n" + line
                   + ("\n\n" if tail else "\n") + tail)
        inserted = True
    if updated == original:
        results.append(("same", label, str(path)))
        return
    if CHECK:
        results.append(("DRIFT", label, str(path)))
        return
    _backup(path)
    path.write_text(updated)
    results.append(("inserted" if inserted else "assigned", label, str(path)))

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
# Neovim
#
# Same split as Helix: the palette table is interpolated, the highlight table
# below addresses it by NAME and never moves when a ramp parameter changes.
#
# Neovim has no theme-inheritance mechanism worth relying on, so the group
# list is exhaustive rather than a set of overrides on top of `default`. It
# covers the built-in UI, both syntax vocabularies (legacy groups and
# treesitter captures), and every plugin this config installs -- plugins
# register their own highlights with `default = true`, which never overwrites
# a group a colorscheme has already defined, so these win regardless of load
# order.
#
# Mode is carried by underline STYLE in the statusline rather than by a
# colour-swapped slab: the mode chip repaints on every insert/normal toggle,
# which is exactly the small high-frequency fill that ghosts on a panel.
#
# The emitted Lua is deliberately NOT column-aligned, unlike every other file
# here. init.lua turns on format-on-save for lua, and stylua collapses padding
# around `=`, so an aligned table would be silently reformatted the first time
# anyone opened the generated file and saved it -- drift that only --check
# would ever notice. The contrast table lives in the header comment instead,
# where a formatter has no opinion.
# --------------------------------------------------------------------------

NVIM_BODY = '''
local groups = {
	-- Editor surface. The page is paper; the two surfaces that are chrome
	-- rather than text -- the statusline band and the transient LSP floats --
	-- sit one step down on cursorline, the same fill the current line uses.
	-- Nothing else takes a second shade behind a whole region.
	Normal = { fg = p.ink, bg = p.paper },
	NormalNC = { fg = p.ink, bg = p.paper },

	-- Hover (K), signature help, the diagnostic float and the completion doc
	-- window all render on NormalFloat. On paper they were indistinguishable
	-- from the buffer behind them, so they take the chrome fill; the border
	-- cells match the body or the ring reads as a gap.
	NormalFloat = { fg = p.ink, bg = p.cursorline },
	FloatBorder = { fg = p.rule, bg = p.cursorline },
	FloatTitle = { fg = p.ink, bg = p.cursorline, bold = true, underline = true, sp = p.ink },
	FloatFooter = { fg = p.muted, bg = p.cursorline },
	WinSeparator = { fg = p.rule, bg = p.paper },
	VertSplit = { link = "WinSeparator" },
	EndOfBuffer = { fg = p.faint },
	Folded = { fg = p.slate, bg = p.cursorline, italic = true },
	FoldColumn = { fg = p.faint, bg = p.paper },
	SignColumn = { fg = p.muted, bg = p.paper },
	ColorColumn = { bg = p.cursorline },
	Conceal = { fg = p.faint },
	Directory = { fg = p.ink, bold = true },
	Title = { fg = p.ink, bold = true },
	Question = { fg = p.ink, bold = true },
	ModeMsg = { fg = p.ink, bold = true },
	MoreMsg = { fg = p.ink, bold = true },
	MsgArea = { fg = p.ink, bg = p.paper },
	MsgSeparator = { fg = p.rule, bg = p.paper },
	ErrorMsg = { fg = p.error, bold = true },
	WarningMsg = { fg = p.warning, bold = true },

	-- Whitespace marks sit at the decoration end of the ramp: present when
	-- looked for, invisible when read past.
	NonText = { fg = p.faint },
	Whitespace = { fg = p.faint },
	SpecialKey = { fg = p.faint },

	-- Gutter
	LineNr = { fg = p.muted, bg = p.paper },
	LineNrAbove = { fg = p.faint, bg = p.paper },
	LineNrBelow = { fg = p.faint, bg = p.paper },
	CursorLineNr = { fg = p.ink, bg = p.cursorline, bold = true },
	CursorLine = { bg = p.cursorline },
	CursorColumn = { bg = p.cursorline },
	CursorLineSign = { bg = p.cursorline },
	CursorLineFold = { bg = p.cursorline },

	-- A solid block is the one high-contrast element e-ink renders well: it
	-- reads as an inked mark rather than as a repaint.
	Cursor = { fg = p.paper, bg = p.ink },
	lCursor = { fg = p.paper, bg = p.ink },
	CursorIM = { fg = p.paper, bg = p.ink },
	TermCursor = { fg = p.paper, bg = p.ink },
	TermCursorNC = { fg = p.paper, bg = p.slate },

	-- Selection and search separate by fill weight, and text stays legible
	-- inside all of them. Only the search cursor inverts.
	Visual = { bg = p.selection },
	VisualNOS = { bg = p.highlight },
	Search = { fg = p.ink, bg = p.highlight },
	CurSearch = { fg = p.paper, bg = p.ink, bold = true },
	IncSearch = { fg = p.paper, bg = p.ink, bold = true },
	Substitute = { fg = p.ink, bg = p.selection, bold = true },
	MatchParen = { fg = p.ink, bg = p.highlight, bold = true },
	QuickFixLine = { bg = p.highlight, bold = true },
	SnippetTabstop = { fg = p.ink, bg = p.highlight },

	-- Statusline, tabline, winbar. The band takes the chrome fill so it
	-- reads as a strip rather than as more page; the MODE within it is still
	-- a mark, not a second fill -- see the MiniStatusline groups at the
	-- bottom. Tabline and winbar stay on paper: they sit against the buffer,
	-- not under it.
	StatusLine = { fg = p.ink, bg = p.cursorline, bold = true },
	StatusLineNC = { fg = p.muted, bg = p.cursorline },
	StatusLineTerm = { link = "StatusLine" },
	StatusLineTermNC = { link = "StatusLineNC" },
	WinBar = { fg = p.ink, bg = p.paper, bold = true },
	WinBarNC = { fg = p.muted, bg = p.paper },
	TabLine = { fg = p.muted, bg = p.paper },
	TabLineFill = { bg = p.paper },
	TabLineSel = { fg = p.ink, bg = p.paper, bold = true, underline = true, sp = p.ink },

	-- Completion menu. The selected row fills; the matched substring is
	-- marked with weight so it survives being read as pure gray.
	Pmenu = { fg = p.ink, bg = p.paper },
	PmenuSel = { fg = p.ink, bg = p.highlight, bold = true },
	PmenuKind = { fg = p.slate, bg = p.paper },
	PmenuKindSel = { fg = p.slate, bg = p.highlight },
	PmenuExtra = { fg = p.muted, bg = p.paper },
	PmenuExtraSel = { fg = p.muted, bg = p.highlight },
	PmenuMatch = { fg = p.ink, bg = p.paper, bold = true },
	PmenuMatchSel = { fg = p.ink, bg = p.highlight, bold = true },
	PmenuSbar = { bg = p.cursorline },
	PmenuThumb = { bg = p.rule },
	WildMenu = { link = "PmenuSel" },

	-- Spelling: style first, hue only where one exists.
	SpellBad = { sp = p.error, undercurl = true },
	SpellCap = { sp = p.slate, underdashed = true },
	SpellLocal = { sp = p.slate, underdotted = true },
	SpellRare = { sp = p.muted, underdotted = true },

	-- Diff windows. Added sits two ramp levels lighter than removed, the
	-- same weight ordering hunk and lazygit use, so the three states are
	-- ranked rather than merely different.
	DiffAdd = { bg = p.cursorline },
	DiffChange = { bg = p.highlight },
	DiffDelete = { fg = p.slate, bg = p.selection },
	DiffText = { bg = p.rule, bold = true },

	-- Diff TEXT, as opposed to diff windows: proofreader's marks, because
	-- there is no green or red to lean on and bold-vs-dim alone is too weak
	-- to scan down a gutter.
	diffAdded = { fg = p.ink, underline = true, sp = p.ink },
	diffRemoved = { fg = p.slate, strikethrough = true },
	diffChanged = { fg = p.charcoal, bold = true },
	diffNewFile = { fg = p.ink, bold = true },
	diffOldFile = { fg = p.slate, bold = true },
	diffFile = { fg = p.ink, bold = true },
	diffLine = { fg = p.muted },
	diffIndexLine = { fg = p.muted },
	Added = { fg = p.ink, bold = true },
	Removed = { fg = p.slate, bold = true },
	Changed = { fg = p.charcoal, bold = true },

	-- Diagnostics: underline style is the primary carrier, weight second,
	-- hue last. Read as gray, curl-vs-dash-vs-dot still tells them apart.
	DiagnosticError = { fg = p.error, bold = true },
	DiagnosticWarn = { fg = p.warning, bold = true },
	DiagnosticInfo = { fg = p.slate },
	DiagnosticHint = { fg = p.muted, italic = true },
	DiagnosticOk = { fg = p.charcoal },
	DiagnosticUnderlineError = { sp = p.error, undercurl = true },
	DiagnosticUnderlineWarn = { sp = p.warning, underdashed = true },
	DiagnosticUnderlineInfo = { sp = p.slate, underdotted = true },
	DiagnosticUnderlineHint = { sp = p.muted, underdotted = true },
	DiagnosticUnderlineOk = { sp = p.charcoal, underdotted = true },
	DiagnosticVirtualTextError = { fg = p.error, italic = true },
	DiagnosticVirtualTextWarn = { fg = p.warning, italic = true },
	DiagnosticVirtualTextInfo = { fg = p.slate, italic = true },
	DiagnosticVirtualTextHint = { fg = p.muted, italic = true },
	DiagnosticVirtualTextOk = { fg = p.charcoal, italic = true },
	DiagnosticFloatingError = { fg = p.error, bold = true },
	DiagnosticFloatingWarn = { fg = p.warning, bold = true },
	DiagnosticFloatingInfo = { fg = p.slate },
	DiagnosticFloatingHint = { fg = p.muted, italic = true },
	DiagnosticFloatingOk = { fg = p.charcoal },
	DiagnosticSignError = { fg = p.error, bg = p.paper, bold = true },
	DiagnosticSignWarn = { fg = p.warning, bg = p.paper, bold = true },
	DiagnosticSignInfo = { fg = p.slate, bg = p.paper },
	DiagnosticSignHint = { fg = p.muted, bg = p.paper },
	DiagnosticSignOk = { fg = p.charcoal, bg = p.paper },
	DiagnosticDeprecated = { fg = p.slate, strikethrough = true },
	DiagnosticUnnecessary = { fg = p.muted, italic = true },

	-- LSP
	LspReferenceText = { bg = p.highlight },
	LspReferenceRead = { bg = p.highlight },
	LspReferenceWrite = { bg = p.selection, bold = true },
	LspReferenceTarget = { bg = p.highlight },
	LspSignatureActiveParameter = { fg = p.ink, bold = true, underline = true, sp = p.ink },
	LspInlayHint = { fg = p.muted, bg = p.paper, italic = true },
	LspCodeLens = { fg = p.muted, italic = true },
	LspCodeLensSeparator = { fg = p.rule },
	LspInfoBorder = { fg = p.rule, bg = p.cursorline },

	-- Syntax, legacy vocabulary. Hierarchy comes from four text tones plus
	-- bold and italic; there is no fifth tone and no hue.
	Comment = { fg = p.muted, italic = true },
	Constant = { fg = p.charcoal, bold = true },
	String = { fg = p.charcoal },
	Character = { fg = p.charcoal },
	Number = { fg = p.charcoal },
	Float = { fg = p.charcoal },
	Boolean = { fg = p.charcoal, bold = true },
	Identifier = { fg = p.ink },
	Function = { fg = p.ink, bold = true },
	Statement = { fg = p.ink, bold = true },
	Conditional = { fg = p.ink, bold = true },
	Repeat = { fg = p.ink, bold = true },
	Label = { fg = p.ink, bold = true },
	Operator = { fg = p.charcoal, bold = true },
	Keyword = { fg = p.ink, bold = true },
	Exception = { fg = p.ink, bold = true },
	PreProc = { fg = p.charcoal, bold = true },
	Include = { fg = p.charcoal, bold = true, italic = true },
	Define = { fg = p.charcoal, bold = true },
	Macro = { fg = p.charcoal, bold = true, italic = true },
	PreCondit = { fg = p.charcoal, bold = true },
	Type = { fg = p.ink, bold = true },
	StorageClass = { fg = p.ink, bold = true },
	Structure = { fg = p.ink, bold = true },
	Typedef = { fg = p.ink, bold = true },
	Special = { fg = p.ink, bold = true },
	SpecialChar = { fg = p.ink, bold = true },
	Tag = { fg = p.ink, bold = true },
	Delimiter = { fg = p.slate },
	SpecialComment = { fg = p.slate, bold = true, italic = true },
	Debug = { fg = p.warning, bold = true },
	Underlined = { underline = true, sp = p.rule },
	Ignore = { fg = p.faint },
	Error = { fg = p.error, bold = true },
	Todo = { fg = p.ink, bg = p.highlight, bold = true },

	-- Syntax, treesitter vocabulary. Mirrors the Helix scope table one to
	-- one, so the same file reads identically in either editor.
	["@variable"] = { fg = p.ink },
	["@variable.builtin"] = { fg = p.charcoal, italic = true },
	["@variable.parameter"] = { fg = p.charcoal, italic = true },
	["@variable.parameter.builtin"] = { fg = p.charcoal, italic = true },
	["@variable.member"] = { fg = p.charcoal },
	["@constant"] = { fg = p.charcoal, bold = true },
	["@constant.builtin"] = { fg = p.ink, bold = true, italic = true },
	["@constant.macro"] = { fg = p.charcoal, bold = true },
	["@module"] = { fg = p.charcoal, italic = true },
	["@module.builtin"] = { fg = p.charcoal, bold = true, italic = true },
	["@label"] = { fg = p.ink, bold = true },
	["@string"] = { fg = p.charcoal },
	["@string.documentation"] = { fg = p.slate, italic = true },
	["@string.regexp"] = { fg = p.ink, italic = true },
	["@string.escape"] = { fg = p.ink, bold = true },
	["@string.special"] = { fg = p.ink, bold = true },
	["@string.special.symbol"] = { fg = p.charcoal },
	["@string.special.path"] = { fg = p.charcoal, italic = true },
	["@string.special.url"] = { fg = p.ink, underline = true, sp = p.ink },
	["@character"] = { fg = p.charcoal },
	["@character.special"] = { fg = p.ink, bold = true },
	["@boolean"] = { fg = p.charcoal, bold = true },
	["@number"] = { fg = p.charcoal },
	["@number.float"] = { fg = p.charcoal },
	["@type"] = { fg = p.ink, bold = true },
	["@type.builtin"] = { fg = p.ink, bold = true, italic = true },
	["@type.definition"] = { fg = p.ink, bold = true },
	["@attribute"] = { fg = p.charcoal, italic = true },
	["@attribute.builtin"] = { fg = p.charcoal, italic = true },
	["@property"] = { fg = p.charcoal },
	["@function"] = { fg = p.ink, bold = true },
	["@function.builtin"] = { fg = p.charcoal, bold = true, italic = true },
	["@function.call"] = { fg = p.ink, bold = true },
	["@function.macro"] = { fg = p.charcoal, bold = true, italic = true },
	["@function.method"] = { fg = p.ink, bold = true },
	["@function.method.call"] = { fg = p.ink, bold = true },
	["@constructor"] = { fg = p.ink, bold = true },
	["@operator"] = { fg = p.charcoal, bold = true },
	["@keyword"] = { fg = p.ink, bold = true },
	["@keyword.coroutine"] = { fg = p.ink, bold = true },
	["@keyword.function"] = { fg = p.ink, bold = true, italic = true },
	["@keyword.operator"] = { fg = p.charcoal, bold = true },
	["@keyword.import"] = { fg = p.charcoal, bold = true, italic = true },
	["@keyword.type"] = { fg = p.ink, bold = true },
	["@keyword.modifier"] = { fg = p.ink, bold = true },
	["@keyword.repeat"] = { fg = p.ink, bold = true },
	["@keyword.return"] = { fg = p.ink, bold = true },
	["@keyword.debug"] = { fg = p.warning, bold = true },
	["@keyword.exception"] = { fg = p.ink, bold = true },
	["@keyword.conditional"] = { fg = p.ink, bold = true },
	["@keyword.conditional.ternary"] = { fg = p.charcoal, bold = true },
	["@keyword.directive"] = { fg = p.charcoal, bold = true, italic = true },
	["@keyword.directive.define"] = { fg = p.charcoal, bold = true, italic = true },
	["@punctuation.delimiter"] = { fg = p.muted },
	["@punctuation.bracket"] = { fg = p.ink },
	["@punctuation.special"] = { fg = p.charcoal, bold = true },
	["@comment"] = { fg = p.muted, italic = true },
	["@comment.documentation"] = { fg = p.slate, italic = true },
	["@comment.error"] = { fg = p.error, bold = true },
	["@comment.warning"] = { fg = p.warning, bold = true },
	["@comment.todo"] = { fg = p.ink, bold = true, underline = true, sp = p.ink },
	["@comment.note"] = { fg = p.slate, bold = true },
	["@tag"] = { fg = p.ink, bold = true },
	["@tag.builtin"] = { fg = p.ink, bold = true },
	["@tag.attribute"] = { fg = p.charcoal, italic = true },
	["@tag.delimiter"] = { fg = p.slate },

	-- Markup follows print convention: heading rank descends by weight,
	-- then by tone. Only rank 1 takes a rule under it.
	["@markup.heading"] = { fg = p.ink, bold = true },
	["@markup.heading.1"] = { fg = p.ink, bold = true, underline = true, sp = p.ink },
	["@markup.heading.2"] = { fg = p.ink, bold = true },
	["@markup.heading.3"] = { fg = p.charcoal, bold = true },
	["@markup.heading.4"] = { fg = p.charcoal, bold = true, italic = true },
	["@markup.heading.5"] = { fg = p.slate, bold = true },
	["@markup.heading.6"] = { fg = p.slate, italic = true },
	["@markup.strong"] = { fg = p.ink, bold = true },
	["@markup.italic"] = { fg = p.charcoal, italic = true },
	["@markup.strikethrough"] = { fg = p.muted, strikethrough = true },
	["@markup.underline"] = { underline = true, sp = p.rule },
	["@markup.quote"] = { fg = p.slate, italic = true },
	["@markup.math"] = { fg = p.charcoal },
	["@markup.link"] = { fg = p.ink },
	["@markup.link.label"] = { fg = p.ink },
	["@markup.link.url"] = { fg = p.charcoal, underline = true, sp = p.rule },
	["@markup.raw"] = { fg = p.charcoal },
	["@markup.raw.block"] = { fg = p.charcoal },
	["@markup.list"] = { fg = p.slate, bold = true },
	["@markup.list.checked"] = { fg = p.ink, bold = true },
	["@markup.list.unchecked"] = { fg = p.muted },
	["@diff.plus"] = { fg = p.ink, underline = true, sp = p.ink },
	["@diff.minus"] = { fg = p.slate, strikethrough = true },
	["@diff.delta"] = { fg = p.charcoal, bold = true, underdotted = true, sp = p.charcoal },

	-- Semantic tokens. Neovim already links @lsp.type.* to the treesitter
	-- captures above; only the two that disagree with a parser are pinned.
	["@lsp.type.comment"] = {},
	["@lsp.mod.deprecated"] = { strikethrough = true },

	-- gitsigns. The gutter signs are "+", "~", "_" characters, so tone and
	-- weight are all that is left to rank them by.
	GitSignsAdd = { fg = p.ink, bg = p.paper, bold = true },
	GitSignsChange = { fg = p.charcoal, bg = p.paper, bold = true },
	GitSignsDelete = { fg = p.slate, bg = p.paper, bold = true },
	GitSignsTopdelete = { link = "GitSignsDelete" },
	GitSignsChangedelete = { link = "GitSignsChange" },
	GitSignsUntracked = { fg = p.muted, bg = p.paper },
	GitSignsAddLn = { bg = p.cursorline },
	GitSignsChangeLn = { bg = p.highlight },
	GitSignsDeleteLn = { bg = p.selection },
	GitSignsAddInline = { bg = p.highlight },
	GitSignsChangeInline = { bg = p.highlight },
	GitSignsDeleteInline = { bg = p.selection, strikethrough = true },
	GitSignsCurrentLineBlame = { fg = p.faint, italic = true },

	-- telescope. Borders are square (set in init.lua), so the rule tone is
	-- doing real work here.
	TelescopeNormal = { fg = p.ink, bg = p.paper },
	TelescopeBorder = { fg = p.rule, bg = p.paper },
	TelescopePromptNormal = { fg = p.ink, bg = p.paper },
	TelescopePromptBorder = { fg = p.rule, bg = p.paper },
	TelescopePromptPrefix = { fg = p.ink, bold = true },
	TelescopePromptCounter = { fg = p.muted },
	TelescopeTitle = { fg = p.ink, bg = p.paper, bold = true, underline = true, sp = p.ink },
	TelescopePromptTitle = { link = "TelescopeTitle" },
	TelescopeResultsTitle = { link = "TelescopeTitle" },
	TelescopePreviewTitle = { link = "TelescopeTitle" },
	TelescopeSelection = { fg = p.ink, bg = p.highlight, bold = true },
	TelescopeSelectionCaret = { fg = p.ink, bg = p.highlight, bold = true },
	TelescopeMultiSelection = { fg = p.ink, bg = p.selection },
	TelescopeMultiIcon = { fg = p.ink, bold = true },
	TelescopeMatching = { fg = p.ink, bold = true, underline = true, sp = p.ink },
	TelescopePreviewLine = { bg = p.cursorline },
	TelescopeResultsComment = { fg = p.muted, italic = true },
	TelescopeResultsDiffAdd = { fg = p.ink, bold = true },
	TelescopeResultsDiffChange = { fg = p.charcoal, bold = true },
	TelescopeResultsDiffDelete = { fg = p.slate, bold = true },
	TelescopeResultsDiffUntracked = { fg = p.muted },

	-- which-key
	WhichKey = { fg = p.ink, bold = true },
	WhichKeyGroup = { fg = p.charcoal, bold = true },
	WhichKeyDesc = { fg = p.ink },
	WhichKeySeparator = { fg = p.rule },
	WhichKeyValue = { fg = p.muted },
	WhichKeyIcon = { fg = p.slate },
	WhichKeyNormal = { fg = p.ink, bg = p.paper },
	WhichKeyBorder = { fg = p.rule, bg = p.paper },
	WhichKeyTitle = { fg = p.ink, bg = p.paper, bold = true, underline = true, sp = p.ink },

	-- oil
	OilDir = { fg = p.ink, bold = true },
	OilDirIcon = { fg = p.slate },
	OilFile = { fg = p.ink },
	OilLink = { fg = p.slate, italic = true },
	OilLinkTarget = { fg = p.slate, italic = true },
	OilSocket = { fg = p.charcoal, italic = true },
	OilCreate = { fg = p.ink, bold = true },
	OilCopy = { fg = p.charcoal, bold = true },
	OilMove = { fg = p.charcoal, bold = true },
	OilChange = { fg = p.charcoal, bold = true },
	OilDelete = { fg = p.slate, bold = true, strikethrough = true },
	OilPurge = { fg = p.error, bold = true },
	OilTrash = { fg = p.slate, bold = true },
	OilTrashSourcePath = { fg = p.muted, italic = true },
	OilRestore = { fg = p.ink, bold = true },

	-- fidget
	FidgetTitle = { fg = p.ink, bold = true },
	FidgetTask = { fg = p.muted },

	-- mason
	MasonHeader = { fg = p.paper, bg = p.ink, bold = true },
	MasonHeaderSecondary = { fg = p.paper, bg = p.slate, bold = true },
	MasonHighlight = { fg = p.ink, bold = true },
	MasonHighlightBlock = { fg = p.ink, bg = p.highlight, bold = true },
	MasonHighlightBlockBold = { fg = p.ink, bg = p.selection, bold = true },
	MasonMuted = { fg = p.muted },
	MasonMutedBlock = { fg = p.slate, bg = p.cursorline },
	MasonError = { fg = p.error, bold = true },
	MasonWarning = { fg = p.warning, bold = true },
	MasonHeading = { fg = p.ink, bold = true, underline = true, sp = p.ink },

	-- mini.statusline draws the band, so every section carries the chrome
	-- fill; a chip left on paper would be a hole in the strip. The mode chip
	-- repaints on every mode switch, which is exactly the small
	-- high-frequency fill that ghosts, so mode is carried by underline STYLE
	-- over that one fill -- the same trick the Helix statusline uses,
	-- extended to cover Neovim's six modes.
	MiniStatuslineModeNormal = { fg = p.ink, bg = p.cursorline, bold = true },
	MiniStatuslineModeInsert = { fg = p.ink, bg = p.cursorline, bold = true, underline = true, sp = p.ink },
	MiniStatuslineModeVisual = { fg = p.ink, bg = p.cursorline, bold = true, italic = true },
	MiniStatuslineModeReplace = { fg = p.ink, bg = p.cursorline, bold = true, undercurl = true, sp = p.ink },
	MiniStatuslineModeCommand = { fg = p.ink, bg = p.cursorline, bold = true, underdouble = true, sp = p.ink },
	MiniStatuslineModeOther = { fg = p.ink, bg = p.cursorline, bold = true, underdotted = true, sp = p.ink },
	MiniStatuslineDevinfo = { fg = p.slate, bg = p.cursorline },
	MiniStatuslineFilename = { fg = p.charcoal, bg = p.cursorline },
	MiniStatuslineFileinfo = { fg = p.muted, bg = p.cursorline },
	MiniStatuslineInactive = { fg = p.muted, bg = p.cursorline },

	-- mini.surround / mini.icons. The icon groups are named after hues this
	-- palette does not have; each is folded onto the nearest text tone so a
	-- nerd font cannot smuggle colour back in.
	MiniSurround = { fg = p.ink, bg = p.highlight, bold = true },
	MiniIconsAzure = { fg = p.slate },
	MiniIconsBlue = { fg = p.slate },
	MiniIconsCyan = { fg = p.slate },
	MiniIconsGreen = { fg = p.charcoal },
	MiniIconsGrey = { fg = p.muted },
	MiniIconsOrange = { fg = p.charcoal },
	MiniIconsPurple = { fg = p.charcoal },
	MiniIconsRed = { fg = p.ink },
	MiniIconsYellow = { fg = p.slate },
}

for group, spec in pairs(groups) do
	vim.api.nvim_set_hl(0, group, spec)
end

-- todo-comments is deliberately absent: its TODO/FIX/NOTE groups are derived
-- from the Diagnostic* groups above, so it follows the palette on its own.
-- It is set to `keyword = "wide_fg"` in init.lua for the same reason every
-- other surface here avoids fills -- a coloured slab behind a keyword is the
-- one thing a panel repaints worst.
'''


def emit_nvim():
    lv = P["roles"]
    names = ("ink", "charcoal", "slate", "muted", "faint", "rule",
             "selection", "highlight", "cursorline", "paper")
    table, rows = [], []
    for name in names:
        c = contrast(R[name], paper)
        grade = "AAA" if c >= 7 else "AA" if c >= 4.5 else "decoration"
        if name == "paper":
            grade, ratio = "the page itself", "-------"
        else:
            ratio = f"{c:5.2f}:1"
        table.append(f"--   {name:<10} L{lv[name]:<2}  {R[name]}  {ratio}  {grade}")
        rows.append(f'\t{name} = "{R[name]}",')
    table.append(f"--   {'error':<10} off  {ERROR}  {contrast(ERROR, paper):5.2f}:1  AAA")
    table.append(f"--   {'warning':<10} off  {WARNING}  {contrast(WARNING, paper):5.2f}:1  AA; always bold + dashed")
    rows.append(f'\terror = "{ERROR}",')
    rows.append(f'\twarning = "{WARNING}",')
    head = f'''-- e-ink for Neovim -- an E Ink Carta panel simulated on an emissive display.
-- {BANNER}
--
-- 4-bit panel: 16 gray levels, no more. Reflective, so the range stops at
-- {contrast(ink, paper):.2f}:1 -- neither pure white nor pure black appears. Paper is matched
-- to the desktop wallpaper exactly; the warm cast tapers from chroma
-- {_r['chroma']} at paper to {_c_ink} at ink, so the page is cream and the text on it
-- stays near-neutral, as on real stock. Large fills ghost on repaint, so
-- weight, rule and proofreader's mark carry signal instead of slabs; the two
-- exceptions are chrome rather than text -- the statusline band and the
-- transient LSP floats sit on cursorline so they read as something other
-- than more page.

vim.cmd.highlight("clear")
if vim.fn.exists("syntax_on") == 1 then
\tvim.cmd.syntax("reset")
end

-- A 16-level ramp needs 24-bit colour; there is no 256-colour degradation of
-- this theme, and asking for one would mean inventing values off the ramp.
vim.o.termguicolors = true
vim.o.background = "light"
vim.g.colors_name = "eink"

-- {_r['levels']}-step Carta ramp: oklch(L {_r['l_min']} -> {_r['l_max']}, C {_r['chroma']}, h {_r['hue']}).
--
{chr(10).join(table)}
--
-- The two accents are the only off-ramp values and the only hue in the
-- system, separated by luminance ({contrast(ERROR, WARNING):.2f}:1) so they survive being read
-- as pure gray.
local p = {{
{chr(10).join(rows)}
}}
'''
    term = "\n".join(f'vim.g.terminal_color_{i} = "{c}"' for i, c in enumerate(ANSI))
    tail = f'''
-- :terminal, bound to the same ANSI table Ghostty gets, so a command run
-- inside Neovim and the same command run in the bare terminal are coloured
-- identically.
{term}
'''
    write(CFG / "nvim/colors/eink.lua", head + NVIM_BODY + tail, "nvim")
    # `winborder` is geometry rather than colour, but it belongs to the theme
    # for the same reason ghostty's font-thicken does: a hairline frame is how
    # this palette separates a panel from the page, and FloatBorder has nothing
    # to draw without it. Neovim's built-in K and <C-k> pass no border of their
    # own, so the global default is the only lever that reaches them. "single"
    # is the same square box telescope draws from `square_border` in init.lua.
    splice(CFG / "nvim/init.lua",
           '-- The colorscheme itself is generated into nvim/colors/eink.lua and is\n'
           '-- loaded by name like any other theme. Nothing to configure here.\n'
           'vim.cmd.colorscheme("eink")\n'
           '\n'
           '-- Frame every float that does not bring its own border, so hover (K),\n'
           "-- signature help and the diagnostic float get the rule tone drawn around\n"
           '-- them. Square, to match the telescope pickers above.\n'
           'vim.o.winborder = "single"',
           "nvim:assign", comment="--")

# --------------------------------------------------------------------------
# Ghostty
#
# The ANSI table is the shared one defined above, so the terminal and Neovim's
# :terminal cannot drift apart.
# --------------------------------------------------------------------------

def emit_ghostty():
    lines = [f"# E-Ink. {BANNER}",
             "# ANSI red/yellow carry the accents; everything else is the Carta ramp.",
             ""]
    lines += [f"palette = {i}={c}" for i, c in enumerate(ANSI)]
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

# --------------------------------------------------------------------------
# jay
#
# Schema taken from the shipped parser (jay-toml-config-0.14.0,
# src/config/parsers/theme.rs): sixteen colour keys, every one optional and
# every one falling back to jay's own default when absent. Absent is therefore
# not neutral -- jay's defaults are a dark desktop (background #001019, bar
# #000000, highlight a purple wash), so an unset key is a dark-theme colour
# sitting in the middle of a paper one. All sixteen are set here for that
# reason, not for completeness.
#
# Everything separates by VALUE, the way the rest of the system does. The three
# focus states have no third fill available -- levels 13 and 14 are already
# spent on focused and unfocused and the ramp has nothing between them -- so
# focused-inactive keeps the focused FILL and steps only its text down:
#
#   ink      on highlight   10.66:1   focused
#   charcoal on highlight    7.49:1   focused, seat's attention elsewhere
#   muted    on cursorline   4.77:1   unfocused
#
# focused-border-color is set explicitly because jay falls back to border-color
# for it rather than to anything focus-aware (jay-compositor theme.rs,
# focused_border_color), so omitting it drops the border cue altogether. ink
# focused against rule unfocused is the same pair emit_niri writes, which is
# what makes the two compositors read as one desktop.
#
# THREE KEYS ARE FILLS UNDER TEXT THAT CANNOT BE ADJUSTED WITH THEM. jay pins
# the text of an attention-requested title to unfocused-title-text-color
# (tree/container.rs) and the label of a captured workspace button to the
# focused/unfocused title text (tree/output.rs), so an accent fill cannot be
# paid for by lightening its label: muted on error measures 1.34:1, ink on
# warning 2.93:1. The accents go there anyway. eink.toml reserves them for
# exactly this job -- catching a state in peripheral vision matters more than
# purity -- and read as pure gray they still land as dark slabs (error 7.35:1,
# warning 4.83:1, 1.52:1 apart), which is the whole signal. What is lost is the
# title string while the state is up, and it returns the moment the window is
# focused or the capture ends. Both captured keys take warning; focused and
# unfocused captured workspaces stay apart by their label colour alone.
#
# highlight-color is the drag-target and workspace-switch wash, filled OVER
# window content (renderer.rs render_highlight), so it is the only value in the
# system that needs alpha. It darkens instead of glowing for the same reason
# the niri burn does: every window here is already near paper white, so
# anything added clips to white and the cue disappears.
# --------------------------------------------------------------------------

def emit_jay():
    p = CFG / "jay/config.toml"
    for key, val, label in (
        ("bg-color", highlight, "bg"),
        ("bar-bg-color", paper, "bar"),
        ("bar-status-text-color", ink, "bartx"),
        ("border-color", rule, "border"),
        ("focused-border-color", ink, "fborder"),
        ("separator-color", rule, "sep"),
        ("unfocused-title-bg-color", cursorline, "utbg"),
        ("unfocused-title-text-color", muted, "uttx"),
        ("focused-title-bg-color", highlight, "ftbg"),
        ("focused-title-text-color", ink, "fttx"),
        ("focused-inactive-title-bg-color", highlight, "fitbg"),
        ("focused-inactive-title-text-color", charcoal, "fittx"),
        ("attention-requested-bg-color", ERROR, "attn"),
        ("captured-focused-title-bg-color", WARNING, "cftbg"),
        ("captured-unfocused-title-bg-color", WARNING, "cutbg"),
        ("highlight-color", ink + "33", "hl"),
    ):
        set_toml_key(p, "theme", key, val, f"jay:{label}")

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
    "helix/themes/eink.toml", "nvim/colors/eink.lua",
    "ghostty/themes/E-Ink", "yazi/theme.toml",
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
        # The optional trailing pair is alpha (jay's highlight-color). Without
        # it the token would not match AT ALL -- \b fails against the seventh
        # hex digit -- so an off-ramp colour could hide behind an alpha suffix
        # and the audit would report OK. Alpha itself is not a palette value,
        # so it is dropped before the comparison below.
        found  = {h.lower() for h in re.findall(r"#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?\b", txt)}
        found |= {"#" + h.lower() for h in re.findall(r"^set -g \S+ ([0-9a-f]{6})", txt, re.M)}
        found |= {"#" + h.lower() for h in re.findall(r"--background=([0-9a-f]{6})", txt)}
        bad = sorted(h for h in found if h[:7] not in allowed)
        total += len(found); strays += len(bad)
        print(f"  {'OK   ' if not bad else 'STRAY'} {t:<34} {len(found):>2}"
              + ("" if not bad else f"  {bad}"))
    print(f"\n  {total} colour references across {len(AUDIT_TARGETS)} files, "
          f"{strays} not from the ramp")
    print(f"  paper {RAMP[-1]}   ink {RAMP[0]}   range {contrast(RAMP[0], RAMP[-1]):.2f}:1")
    if strays:
        sys.exit(1)

def main():
    for fn in (emit_helix, emit_nvim, emit_ghostty, emit_yazi, emit_btop, emit_mako,
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
