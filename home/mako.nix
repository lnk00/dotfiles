{ pkgs, ... }:

let
  eg = import ./earl-grey.nix pkgs;
in
{
  # D-Bus-activated on the first notification; nothing to autostart
  services.mako = {
    enable = true;
    settings = {
      # mako's default keeps every notification until it's clicked
      default-timeout = 5000;
      # Helix's earl_grey: a popup like hx's help (ui.help), edged like fuzzel and Jay's
      # split lines (ui.window)
      background-color = eg.deepspace;
      text-color = eg.snow;
      border-color = eg.space;
      progress-color = "over ${eg.lacquer}";
      "urgency=critical" = {
        default-timeout = 0;
        # Helix's error colour
        border-color = eg.blush;
      };
    };
  };
}
