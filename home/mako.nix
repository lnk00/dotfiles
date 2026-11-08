{ frost, theme, ... }:

let
  inherit (frost) hash;
in
{
  # D-Bus-activated on the first notification; nothing to autostart
  services.mako = {
    enable = true;
    settings = {
      font = "JetBrainsMono Nerd Font Mono 10";
      # translucent, so mango's layer blur frosts it like fuzzel
      background-color = "#${theme.bg}${theme.glass}";
      text-color = hash theme.fg;
      # same as mango's window borders
      border-color = "#${theme.border}cc";
      progress-color = "over ${hash theme.selStrong}";
      border-size = 2;
      border-radius = theme.radius;
      padding = 14;
      margin = 8;
      width = 360;
      max-icon-size = 48;
      default-timeout = 5000;

      "urgency=low".text-color = hash theme.fgDim;
      "urgency=critical" = {
        border-color = hash theme.red;
        default-timeout = 0;
      };
    };
  };
}
