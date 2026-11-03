{ lib, config, ... }:

{
  # xdpw tries slurp first, which can only pick a monitor; a dmenu chooser also lists windows
  xdg.configFile."xdg-desktop-portal-wlr/config".text = ''
    [screencast]
    chooser_type=dmenu
    chooser_cmd=${lib.getExe config.programs.fuzzel.package} -d -l 10 -p 'Share: '
  '';
}
