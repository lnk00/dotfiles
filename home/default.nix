{ pkgs, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./jay.nix
    ./foot.nix
    ./helix.nix
    ./zen.nix
    ./zen-home.nix
    ./tridactyl.nix
    ./hunk.nix
    ./screenshot.nix
    ./clipboard.nix
    ./fuzzel.nix
    ./mako.nix
    ./fastfetch.nix
    ./cliamp.nix
    ./voxtype.nix
  ];

  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    ripgrep
    bat
    lazygit
    lazydocker
    lazysql
    eza
    bluetui
  ];

  programs.yazi.enable = true;
  programs.btop.enable = true;

  # dark GTK apps and dark websites: the gtk portal hands this to Zen as
  # org.freedesktop.appearance color-scheme, which drives prefers-color-scheme
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications."x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
}
