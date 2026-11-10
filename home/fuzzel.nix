{ theme, ... }:

let
  # fuzzel wants bare RRGGBBAA
  solid = c: "${c}ff";
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
        background = theme.bg + theme.glass;
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
        # the window borders' colour, a little translucent
        border = "${theme.border}cc";
      };
      border = {
        width = 2;
        radius = theme.radius;
        selection-radius = 0;
      };
    };
  };
}
