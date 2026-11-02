{ frost, variant, ... }:

let
  footColors = v: {
    alpha = v.termAlpha;
    alpha-mode = "matching";
    background = v.bg;
    foreground = v.fg;
    cursor = "${v.bg} ${v.accent}";
    selection-background = v.sel;
    selection-foreground = v.fg;
    regular0 = v.black;
    regular1 = v.red;
    regular2 = v.green;
    regular3 = v.yellow;
    regular4 = v.blue;
    regular5 = v.magenta;
    regular6 = v.cyan;
    regular7 = v.white;
    bright0 = v.brBlack;
    bright1 = v.brRed;
    bright2 = v.brGreen;
    bright3 = v.brYellow;
    bright4 = v.brBlue;
    bright5 = v.brMagenta;
    bright6 = v.brCyan;
    bright7 = v.brWhite;
  };
in
{
  programs.foot = {
    enable = true;
    settings = {
      main.font = "JetBrainsMono Nerd Font Mono:size=10";
      main.font-bold = "JetBrainsMono Nerd Font Mono:style=Bold:size=10";
      main.font-italic = "JetBrainsMono Nerd Font Mono:style=Italic:size=10";
      main.font-bold-italic = "JetBrainsMono Nerd Font Mono:style=Bold Italic:size=10";
      main.pad = "14x14";
      main.initial-color-theme = variant;
      key-bindings.pipe-scrollback =
        ''[sh -c "f=$(mktemp --suffix=.log) && cat - > \"$f\" && foot hx \"$f\"; rm -f \"$f\""] Mod1+space'';
      key-bindings.color-theme-toggle = "Control+Shift+t";
      # Ctrl+i/k/h/l as distinct sequences (else Tab, Backspace, …); shell.nix binds them
      text-bindings."\\x1b[105;5u" = "Control+i";
      text-bindings."\\x1b[107;5u" = "Control+k";
      text-bindings."\\x1b[104;5u" = "Control+h";
      text-bindings."\\x1b[108;5u" = "Control+l";

      colors-light = footColors frost.light;
      colors-dark = footColors frost.dark;
    };
  };
}
