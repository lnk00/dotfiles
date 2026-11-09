{ lib, pkgs, ... }:

let
  frost = import ./palette.nix;

  # The single system-wide switch: "light", "dark" or "eink". Every home module derives
  # from it, so changing this one word rethemes foot, helix, yazi, hyprland, fuzzel and mako
  # together. foot still carries a light and a dark palette and can toggle at runtime.
  variant = "light";

  # for programs that only know light and dark; eink is paper, so light
  scheme = if variant == "dark" then "dark" else "light";
in
{
  # Every other home module takes these as plain arguments:
  # { frost, variant, scheme, theme, ... }:
  _module.args = {
    inherit frost variant scheme;
    theme = frost.${variant} // {
      # termAlpha as an RRGGBBAA alpha byte, so layer surfaces frost like foot
      glass = lib.toLower (lib.toHexString (builtins.floor (frost.${variant}.termAlpha * 255 + 0.5)));
      # corner radius for windows and popups: square in every variant
      radius = 0;
    };
  };

  # The desktop-wide light/dark preference, served over the portal as
  # org.freedesktop.appearance color-scheme. Chromium, Electron and GTK apps
  # read it to pick their own variant, so it follows `variant` above.
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if variant == "dark" then "prefer-dark" else "prefer-light";

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
  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = variant == "dark";
  gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = variant == "dark";
}
