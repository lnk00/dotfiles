{ pkgs, ... }:

{
  # Native messenger lets Tridactyl source tridactylrc on startup
  programs.zen-browser.nativeMessagingHosts = [ pkgs.tridactyl-native ];

  xdg.configFile."tridactyl/tridactylrc".text = ''
    set allowautofocus false
  '';
}
