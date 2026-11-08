{ frost, theme, ... }:

let
  inherit (frost) hash;
in
{
  # fastfetch takes "#rrggbb" and emits 24-bit escapes, so it reaches the
  # lavender accent, which none of foot's 16 ANSI slots carry. Like mako it
  # reads `theme`, so it follows `variant` rather than foot's runtime toggle.
  programs.fastfetch = {
    enable = true;
    settings = {
      # the NixOS logo alternates two tones over six slots (odd blue, even
      # cyan); here lavender lambdas alternate with grey ones
      logo.color = {
        "1" = hash theme.accent;
        "2" = hash theme.fgDim;
        "3" = hash theme.accent;
        "4" = hash theme.fgDim;
        "5" = hash theme.accent;
        "6" = hash theme.fgDim;
      };
      display.color = {
        # same as btop: the accent carries the labels, structure recedes
        keys = hash theme.accent;
        title = hash theme.accent;
        output = hash theme.fg;
        separator = hash theme.fgSubtle;
      };
      modules = [
        "title"
        # the rule under the title recedes like a border
        {
          type = "separator";
          outputColor = hash theme.fgSubtle;
        }
        "os"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "wm"
        "terminal"
        "cpu"
        "gpu"
        "memory"
        "disk"
        "break"
        # foot's 16 ANSI slots, i.e. the palette as every other tool sees it.
        # "block" draws foreground glyphs; the default background style sends
        # SGR 5 for the bright row, which foot renders as blinking
        {
          type = "colors";
          symbol = "block";
        }
      ];
    };
  };
}
