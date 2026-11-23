{ ... }:

{
  programs.foot = {
    enable = true;
    settings = {
      main.font = "JetBrainsMono Nerd Font Mono:size=10";
      main.font-bold = "JetBrainsMono Nerd Font Mono:style=Bold:size=10";
      main.font-italic = "JetBrainsMono Nerd Font Mono:style=Italic:size=10";
      main.font-bold-italic = "JetBrainsMono Nerd Font Mono:style=Bold Italic:size=10";
      main.pad = "14x14";
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
