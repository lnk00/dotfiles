{ ... }:

let
  frost = import ./palette.nix;

  # The single system-wide switch: "light" or "dark". Every home module derives
  # from it, so changing this one word rethemes foot, helix, yazi, mango and fuzzel
  # together. foot still carries both palettes and can toggle at runtime.
  variant = "dark";
in
{
  # Every other home module takes these as plain arguments:
  # { frost, variant, theme, ... }:
  _module.args = {
    inherit frost variant;
    theme = frost.${variant};
  };

  # The desktop-wide light/dark preference, served over the portal as
  # org.freedesktop.appearance color-scheme. Chromium, Electron and GTK apps
  # read it to pick their own variant, so it follows `variant` above.
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if variant == "dark" then "prefer-dark" else "prefer-light";

  gtk.enable = true;
  gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = variant == "dark";
  gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = variant == "dark";
}
