# Earl Grey — the palette every themed program draws from.
#
# Derived from helix's built-in earl_grey theme (Steven Vancoillie): a
# migraine-friendly, near-greyscale scheme whose only real colour is the
# lavender "earl" accent, with muted Catppuccin-Frappé hues for diagnostics.
# earl_grey ships dark only; this is a light take on it — same structure, same
# lavender accent, hues darkened for a pale background — warmed onto paper, so
# toggling the reading-mode shader (hyprland.nix) barely changes it.
#
# Colours are bare 6-digit hex, no prefix, because that is the one form every
# consumer can cheaply convert from: helix wants "#rrggbb" (theme.nix's `hash`),
# Hyprland wants "rgba(rrggbbaa)", foot wants it bare.
#
# Warmed from the neutral light (old value after each): every grey keeps its
# Rec.601 luma but moves onto reading_mode.glsl's ink→paper axis, scaled so
# the old bg lands exactly on the shader's paper; the accent and hues go 60%
# of the way to that warm grey, so they read at the same contrast but quieter.
{
  # surfaces, pale to deep
  bg = "f0ebdb"; # f4f4f4, the shader's paper
  bgAlt = "e6e1d3"; # eaeaea
  bgInset = "dcd7ca"; # e0e0e0
  # text, strong to faint
  fg = "39383a"; # 3a3a3a
  fgDim = "5c5b59"; # 5e5e5e
  # one step above fgFaint: recessive, but readable on bg (gutter numbers)
  fgSubtle = "73716d"; # 757575
  fgFaint = "c1bdb2"; # c4c4c4
  # structure
  sel = "d2cec1"; # d6d6d6
  # the primary selection, a step past sel so it stays visible
  selStrong = "bab6ac"; # bcbcc4
  border = "cbc7bb"; # cfcfcf
  accent = "584c86"; # 5b3fd0
  # hues
  red = "885a59"; # b8484a
  yellow = "81734e"; # 96761f
  green = "637a6b"; # 4c8a6a
  cyan = "527273"; # 2f8389
  blue = "596a7b"; # 44719f
  magenta = "84657e"; # a1559a
  brRed = "9c6e6c"; # cc5d5f
  brYellow = "94865f"; # a98a30
  brGreen = "768d7d"; # 5f9e7d
  brCyan = "678887"; # 439a9f
  brBlue = "6d7d8d"; # 5885b3
  brMagenta = "97798f"; # b36aab
  # ansi endpoints
  black = "39383a"; # 3a3a3a
  white = "d2cec1"; # d6d6d6
  brBlack = "73716d"; # 757575
  brWhite = "fbf5e5"; # ffffff
  # how much of the blurred wallpaper shows through a terminal; 0.85 let bright
  # wallpaper shapes compete with text on paper
  termAlpha = 0.95;
}
