{ pkgs, ... }:

{
  imports = [
    ./theme.nix
    ./shell.nix
    ./git.nix
    ./mango.nix
    ./foot.nix
    ./helix.nix
    ./yazi.nix
    ./zen.nix
    ./tridactyl.nix
    ./hunk.nix
    ./screenshot.nix
    ./clipboard.nix
    ./screenshare.nix
    ./fuzzel.nix
    ./mako.nix
    ./clock.nix
    ./btop.nix
    ./cliamp.nix
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

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications."x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
}
