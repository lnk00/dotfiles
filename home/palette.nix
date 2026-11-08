# Earl Grey — the shared palette for every themed program.
#
# Ported from helix's built-in earl_grey theme (Steven Vancoillie): a
# migraine-friendly, near-greyscale scheme whose only real colour is the
# lavender "earl" accent, with muted Catppuccin-Frappé hues for diagnostics.
#
# Colours are bare 6-digit hex, no prefix, because that is the one form every
# consumer can cheaply convert from: helix wants "#rrggbb", mango wants
# "0xrrggbbaa", foot wants it bare. Use the helpers at the bottom.
#
# Every variant carries the same token names, so a program's theme is written
# once as a function of a variant and then applied to each.
#
# earl_grey ships dark only. The dark variant below is a direct port; the
# light variant is derived from it — same structure, same lavender accent,
# hues darkened for a pale background — and then warmed onto paper, so that
# toggling the reading-mode shader (hyprland.nix) barely changes it.
#
# Dark tokens that earl_grey has no colour for are interpolated from its ramp
# and marked (+). Its palette names are given for the ones that are verbatim.

rec {
  # Warmed from the neutral light (old value after each): every grey keeps its
  # Rec.601 luma but moves onto reading_mode.glsl's ink→paper axis, scaled so
  # the old bg lands exactly on the shader's paper; the accent and hues go 60%
  # of the way to that warm grey, so they read at the same contrast but quieter.
  light = {
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
    orange = "8d7055"; # b06a2c
    yellow = "81734e"; # 96761f
    green = "637a6b"; # 4c8a6a
    cyan = "527273"; # 2f8389
    blue = "596a7b"; # 44719f
    magenta = "84657e"; # a1559a
    brRed = "9c6e6c"; # cc5d5f
    brOrange = "a18467"; # c47f3f
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
  };

  dark = {
    bg = "101010"; # chaotica
    bgAlt = "1b1b1b"; # deepspace
    bgInset = "232323"; # (+) between deepspace and space, so popups lift off bgAlt
    fg = "a6a6a6"; # silver
    fgDim = "909090"; # (+) silver rendered "dim", as earl_grey asks for comments
    fgSubtle = "808080"; # grey — earl_grey's own line-number colour
    fgFaint = "2a2a2d"; # space
    sel = "3e3e3e"; # lacquer
    selStrong = "4e4e54"; # (+) lacquer lifted, so the selection shows through termAlpha
    border = "2a2a2d"; # space
    accent = "b59efc"; # earl
    red = "e78284"; # blush
    orange = "ef9f76"; # (+) Frappé peach; earl_grey has no orange
    yellow = "e5c890"; # maple
    green = "90b99f"; # jade
    cyan = "81c8be"; # (+) Frappé teal; earl_grey has no cyan
    blue = "99bbe0"; # sky
    magenta = "e29eca"; # myrtle
    brRed = "f09b9d"; # (+) the bright ramp is each hue lifted ~10%
    brOrange = "f5b595";
    brYellow = "f0d8ab";
    brGreen = "a9cdb6";
    brCyan = "9dd6ce";
    brBlue = "b3cdea";
    brMagenta = "ebb6d9";
    black = "1b1b1b"; # deepspace
    white = "a6a6a6"; # silver
    brBlack = "505050"; # darkgrey
    brWhite = "f0f0f0"; # snow
    termAlpha = 0.8;
  };

  # E-ink paper, after snes19xx's reading_mode.glsl (hyprland.nix): bg and accent
  # are its paper and ink, so toggling the shader off barely moves the tone.
  # Hues are muted until they read on paper at 4.5:1; the shader greys them anyway.
  # brWhite is the darkest ink, not the lightest paper: every program pairs it
  # with selStrong as selected text, and "bright" on paper means more ink.
  eink = {
    bg = "f0ebdb"; # paper 0.94 0.92 0.86
    bgAlt = "e7e1cf";
    bgInset = "ddd6c2";
    fg = "2b2b2b"; # soft charcoal
    fgDim = "4f4c45";
    fgSubtle = "6f6b61";
    fgFaint = "cbc4ae";
    sel = "d8cfb6";
    selStrong = "c4b99c";
    border = "a8a08a";
    accent = "1a1a1f"; # ink 0.10 0.10 0.12
    red = "7a2e2a";
    orange = "8a5a2c";
    yellow = "7a6524";
    green = "4a6a4c";
    cyan = "3a6b68";
    blue = "3c5a7a";
    magenta = "6e3f66";
    brRed = "944540";
    brOrange = "a06d3c";
    brYellow = "8f7a33";
    brGreen = "5c7d5e";
    brCyan = "4a7d7a";
    brBlue = "4f6d8e";
    brMagenta = "84557a";
    black = "2b2b2b";
    white = "d8cfb6";
    brBlack = "6f6b61";
    brWhite = "1a1a1f";
    # e-ink is opaque: no glass, no blur behind it
    termAlpha = 1.0;
  };

  # "eef3f8" -> "#eef3f8"       (helix, most GUI toolkits)
  hash = c: "#${c}";
  # "eef3f8" -> "0xeef3f8ff"    (mango)
  opaque = c: "0x${c}ff";
  # "0a" is the alpha byte      (mango shadows, dim overlays)
  withAlpha = a: c: "0x${c}${a}";
}
