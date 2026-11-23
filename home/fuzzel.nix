{ lib, pkgs, ... }:

let
  # fuzzel wants rrggbbaa
  c = lib.mapAttrs (_: hex: "${lib.removePrefix "#" hex}ff") (import ./earl-grey.nix pkgs);
in
{
  programs.fuzzel = {
    enable = true;
    # for .desktop entries with Terminal=true
    settings.main.terminal = "foot";
    # square corners, like the rest of the desktop
    settings.border.radius = 0;
    # Helix's earl_grey, drawn like hx's own menus (ui.menu, ui.menu.selected); matches
    # and the prompt take the accent, earl
    settings.colors = {
      background = c.deepspace;
      text = c.snow;
      input = c.snow;
      message = c.silver;
      placeholder = c.grey;
      counter = c.grey;
      prompt = c.earl;
      match = c.earl;
      selection = c.lacquer;
      selection-text = c.snow;
      selection-match = c.earl;
      # like Jay's split lines (ui.window)
      border = c.space;
    };
  };
}
