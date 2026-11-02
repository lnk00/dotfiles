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
# Both variants carry the same token names, so a program's theme is written
# once as a function of a variant and then applied to each.
#
# earl_grey ships dark only. The dark variant below is a direct port; the
# light variant is derived from it — same structure, same lavender accent,
# hues darkened for a pale background.
#
# Dark tokens that earl_grey has no colour for are interpolated from its ramp
# and marked (+). Its palette names are given for the ones that are verbatim.

rec {
  light = {
    # surfaces, pale to deep
    bg = "f4f4f4";
    bgAlt = "eaeaea";
    bgInset = "e0e0e0";
    # text, strong to faint
    fg = "3a3a3a";
    fgDim = "5e5e5e";
    # one step above fgFaint: recessive, but readable on bg (gutter numbers)
    fgSubtle = "757575";
    fgFaint = "c4c4c4";
    # structure
    sel = "d6d6d6";
    # the primary selection, a step past sel so it stays visible
    selStrong = "bcbcc4";
    border = "cfcfcf";
    accent = "5b3fd0";
    # hues
    red = "b8484a";
    orange = "b06a2c";
    yellow = "96761f";
    green = "4c8a6a";
    cyan = "2f8389";
    blue = "44719f";
    magenta = "a1559a";
    brRed = "cc5d5f";
    brOrange = "c47f3f";
    brYellow = "a98a30";
    brGreen = "5f9e7d";
    brCyan = "439a9f";
    brBlue = "5885b3";
    brMagenta = "b36aab";
    # ansi endpoints
    black = "3a3a3a";
    white = "d6d6d6";
    brBlack = "757575";
    brWhite = "ffffff";
    # how much of the blurred wallpaper shows through a terminal
    termAlpha = 0.85;
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

  # "eef3f8" -> "#eef3f8"       (helix, most GUI toolkits)
  hash = c: "#${c}";
  # "eef3f8" -> "0xeef3f8ff"    (mango)
  opaque = c: "0x${c}ff";
  # "0a" is the alpha byte      (mango shadows, dim overlays)
  withAlpha = a: c: "0x${c}${a}";
}
