#!/usr/bin/env python3
"""
Render the night plate of the desktop wallpaper from the daylight one.

    python3 ~/.config/theme/wallpaper.py

There is no dark version of this painting to find: it is ink on cream stock,
and cream stock is what it is. So the dark plate is derived rather than
sourced, the same way every other surface on this machine is derived -- the
image is read as one channel of ink density and re-inked onto the dark
palette's own ramp, between its exact paper and its exact ink.

That is what makes it belong. A dark wallpaper found elsewhere would sit at
some other black behind windows whose gaps show it; this one's field IS
`paper` -- within the code or two the grain and the encode cost -- because both
come out of the same four numbers in eink-dark.toml.

The luminance inversion happens in oklab L, not in sRGB bytes: inverting the
stored bytes would drag the midtones -- the whole body of the mist -- far too
bright, and mist is most of this picture.

ffmpeg does the decoding and encoding; the mapping itself is a 256-entry
lookup applied with bytes.translate, so the full 5824x3264 plate costs three
table lookups rather than eleven million Python operations.
"""
import math, subprocess, sys, tomllib
from pathlib import Path

SRC_IMG = Path.home() / "Pictures/Wallpapers/vilkasss-ink-10177251.jpg"
OUT_IMG = SRC_IMG.with_name(SRC_IMG.stem + "-night.jpg")
PALETTE = Path.home() / ".config/theme/eink-dark.toml"

# The plate is DECORATION, and the palette is explicit about where decoration
# lives: at or below `faint`. This matters more here than anywhere else in the
# system, because inversion does something the original never did -- in the
# daylight painting the bright mass is the field and the ink is sparse, so
# flipping it makes the mountains the bright mass, and a window would end up
# sitting on a glowing white slab. Ceilinged at `faint` the mountains come back
# as mist, the picture keeps every one of its gradients, and nothing on the
# desktop has to compete with the wallpaper to be read.
CEILING_ROLE = "faint"

# Dither strength, in 8-bit codes. See the comment at the encode below.
GRAIN = 3

# Reuse the generator's own colour maths so the plate cannot disagree with the
# palette about what paper and ink are.
sys.path.insert(0, str(Path.home() / ".config/theme"))

def oklch_to_hex_rgb(L, C, h):
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
    return tuple(out)

def srgb_to_L(v):
    """oklab lightness of the gray whose sRGB byte is v. For r==g==b the three
    cone responses collapse to the linear value, so L is simply its cube root."""
    c = v / 255
    lin = c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return lin ** (1 / 3)

P = tomllib.load(open(PALETTE, "rb"))
_r, _roles = P["ramp"], P["roles"]
C_PAPER = _r["chroma"]
C_INK   = _r.get("chroma_min", C_PAPER)
HUE     = _r["hue"]
L_PAPER = _r["l_min"]
_steps  = _r["levels"] - 1
_ceil   = _roles[CEILING_ROLE]
L_INK   = _r["l_min"] + (_r["l_max"] - _r["l_min"]) * _ceil / _steps
C_INK   = C_PAPER + (C_INK - C_PAPER) * _ceil / _steps

def ffmpeg(args, stdin=None):
    return subprocess.run(["ffmpeg", "-loglevel", "error", *args],
                          input=stdin, stdout=subprocess.PIPE, check=True).stdout

def main():
    if not SRC_IMG.exists():
        raise SystemExit(f"missing source plate: {SRC_IMG}")

    w, h = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v",
         "-show_entries", "stream=width,height", "-of", "csv=p=0", str(SRC_IMG)],
        capture_output=True, text=True, check=True).stdout.strip().split(",")
    w, h = int(w), int(h)

    gray = ffmpeg(["-i", str(SRC_IMG), "-vf", "format=gray",
                   "-f", "rawvideo", "-pix_fmt", "gray", "-"])
    assert len(gray) == w * h, (len(gray), w * h)

    # Anchor the ends on percentiles rather than on the extremes: a handful of
    # blown-out or crushed pixels must not decide where the whole page sits.
    # The 0.5% tails put the cream field exactly on paper and the darkest ink
    # exactly on ink, which is the entire point of deriving this locally.
    hist = [0] * 256
    for b in gray:
        hist[b] += 1
    total = w * h
    def pct(p):
        want, run = total * p, 0
        for v, n in enumerate(hist):
            run += n
            if run >= want:
                return v
        return 255
    lo, hi = srgb_to_L(pct(0.005)), srgb_to_L(pct(0.995))
    span = max(hi - lo, 1e-6)

    # One entry per possible input byte. t runs 0 at the cream field to 1 at the
    # densest ink, so the picture arrives on the dark ramp already inverted, and
    # the cast tapers across it exactly as it does across the sixteen levels.
    tables = [bytearray(256) for _ in range(3)]
    for v in range(256):
        t = min(1.0, max(0.0, (hi - srgb_to_L(v)) / span))
        rgb = oklch_to_hex_rgb(L_PAPER + (L_INK - L_PAPER) * t,
                               C_PAPER + (C_INK - C_PAPER) * t,
                               HUE)
        for ch in range(3):
            tables[ch][v] = rgb[ch]

    # gbrp is planar, so the three lookups ARE the image; nothing has to be
    # interleaved pixel by pixel on this side.
    planes = (gray.translate(bytes(tables[1])) +
              gray.translate(bytes(tables[2])) +
              gray.translate(bytes(tables[0])))
    # Grain, and not for the look of it. Ceilinged at `faint` the whole picture
    # lives inside about twenty-three 8-bit codes, and a sky that crosses one
    # code every sixty pixels is exactly the shape that shows up as contour
    # banding on a good panel. A little uniform noise puts the transition back
    # below the eye's ability to find an edge. That it also reads as the tooth
    # of the paper is a happy accident of what this palette is about.
    ffmpeg(["-y", "-f", "rawvideo", "-pix_fmt", "gbrp", "-s", f"{w}x{h}",
            "-i", "-", "-vf", f"noise=alls={GRAIN}:allf=u",
            "-frames:v", "1", "-q:v", "2", str(OUT_IMG)], stdin=planes)

    paper = "#%02x%02x%02x" % oklch_to_hex_rgb(L_PAPER, C_PAPER, HUE)
    ink   = "#%02x%02x%02x" % oklch_to_hex_rgb(L_INK, C_INK, HUE)
    print(f"  {SRC_IMG.name}  ->  {OUT_IMG.name}   {w}x{h}")
    print(f"  field {paper} = paper    densest ink {ink} = {CEILING_ROLE}")

if __name__ == "__main__":
    main()
