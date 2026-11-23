{ config, lib, pkgs, ... }:

let
  # yt-dlp reads the YouTube Music sign-in from Zen's (Firefox-format) cookie jar
  seed = pkgs.writeText "cliamp-config.toml" ''
    [ytmusic]
    cookies_from = "firefox:${config.home.homeDirectory}/.config/zen"
  '';
in
{
  home.packages = [ pkgs.cliamp ];

  # cliamp rewrites config.toml itself (theme on every exit, shuffle/repeat/eq on change),
  # so a store symlink would break: seed it once and let cliamp own it afterwards
  home.activation.cliampConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="${config.xdg.configHome}/cliamp/config.toml"
    if [ ! -e "$cfg" ]; then
      run install -D -m 600 ${seed} "$cfg"
    fi
  '';
}
