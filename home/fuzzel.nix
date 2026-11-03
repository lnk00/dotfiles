{ lib, theme, ... }:

let
  # fuzzel wants bare RRGGBBAA
  solid = c: "${c}ff";
  # foot's see-through, so mango's layer blur frosts it the same way
  glass = lib.toLower (lib.toHexString (builtins.floor (theme.termAlpha * 255 + 0.5)));
in
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font Mono:size=10";
        terminal = "foot";
        layer = "overlay";
        horizontal-pad = 14;
        vertical-pad = 14;
        inner-pad = 8;
      };
      colors = {
        background = theme.bg + glass;
        text = solid theme.fg;
        message = solid theme.fgDim;
        prompt = solid theme.fgSubtle;
        placeholder = solid theme.fgSubtle;
        input = solid theme.fg;
        match = solid theme.accent;
        selection = solid theme.selStrong;
        selection-text = solid theme.fg;
        selection-match = solid theme.accent;
        counter = solid theme.fgSubtle;
        # same as mango's window borders
        border = "${theme.border}cc";
      };
      border = {
        width = 2;
        radius = 8;
        selection-radius = 4;
      };
    };
  };
}
