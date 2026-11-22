{ lib, pkgs, ... }:

let
  palette = import ./palette.nix;
in
{
  # Every other home module takes these as plain arguments:
  # { theme, hash, ... }:
  _module.args = {
    # "eef3f8" -> "#eef3f8"       (helix, most GUI toolkits)
    hash = c: "#${c}";
    theme = palette // {
      # termAlpha as an RRGGBBAA alpha byte, so layer surfaces frost like foot
      glass = lib.toLower (lib.toHexString (builtins.floor (palette.termAlpha * 255 + 0.5)));
      # corner radius for windows and popups: square everywhere
      radius = 0;
      # window border width; frame.nix draws the screen frame at the same width
      borderWidth = 2;
    };
  };

  # The desktop-wide light/dark preference, served over the portal as
  # org.freedesktop.appearance color-scheme. Chromium, Electron and GTK apps
  # read it to pick their own light variant.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-light";

  # without one, Hyprland falls back to its own logo as the pointer.
  # HM only exports these as session variables, which greetd never sources,
  # so hyprland.nix also hands them to Hyprland with hl.env.
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
  };

  gtk.enable = true;
}
