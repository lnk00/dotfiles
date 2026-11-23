{ lib, pkgs, ... }:

let
  # foot wants rrggbb
  c = lib.mapAttrs (_: lib.removePrefix "#") (import ./earl-grey.nix pkgs);
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
      # Helix's earl_grey: hx's own background and text, its cursor and selection. The
      # palette has one shade per hue and no cyan, so each ANSI slot takes the nearest hue
      # (earl is a violet blue, sky sits between blue and cyan) and brights repeat them
      colors-dark = {
        background = c.chaotica;
        foreground = c.silver;
        cursor = "${c.black} ${c.earl}";
        selection-foreground = c.snow;
        selection-background = c.lacquer;
        regular0 = c.lacquer;
        regular1 = c.blush;
        regular2 = c.jade;
        regular3 = c.maple;
        regular4 = c.earl;
        regular5 = c.myrtle;
        regular6 = c.sky;
        regular7 = c.silver;
        bright0 = c.grey;
        bright1 = c.blush;
        bright2 = c.jade;
        bright3 = c.maple;
        bright4 = c.earl;
        bright5 = c.myrtle;
        bright6 = c.sky;
        bright7 = c.snow;
      };
      key-bindings.pipe-scrollback =
        ''[sh -c "f=$(mktemp --suffix=.log) && cat - > \"$f\" && foot hx \"$f\"; rm -f \"$f\""] Mod1+space'';
      key-bindings.show-urls-launch = "Control+Shift+o Mod1+u";
      key-bindings.scrollback-up-line = "Mod1+Up";
      key-bindings.scrollback-down-line = "Mod1+Down";
      key-bindings.scrollback-up-half-page = "Control+Mod1+Up";
      key-bindings.scrollback-down-half-page = "Control+Mod1+Down";
      key-bindings.scrollback-up-page = "Mod1+Page_Up Shift+Page_Up";
      key-bindings.scrollback-down-page = "Mod1+Page_Down Shift+Page_Down";
      key-bindings.scrollback-home = "Mod1+Home";
      key-bindings.scrollback-end = "Mod1+End";
      # Ctrl+i/k/h/l as distinct sequences (else Tab, Backspace, …); shell.nix binds them
      text-bindings."\\x1b[105;5u" = "Control+i";
      text-bindings."\\x1b[107;5u" = "Control+k";
      text-bindings."\\x1b[104;5u" = "Control+h";
      text-bindings."\\x1b[108;5u" = "Control+l";
    };
  };
}
