{ config, lib, pkgs, frost, ... }:

let
  inherit (frost) hash;

  # yt-dlp reads the YouTube Music sign-in from Zen's (Firefox-format) cookie jar
  seed = pkgs.writeText "cliamp-config.toml" ''
    [ytmusic]
    cookies_from = "firefox:${config.home.homeDirectory}/.config/zen"
  '';

  # Same restraint as btop: the lavender accent carries the title, seek bar
  # and selection, greys carry the text, and the hues keep their meaning —
  # green playing, yellow warnings, red errors and the favourite heart, which
  # also run the visualizer from low to high. No bg, so foot's translucency
  # shows through like helix and btop.
  cliampTheme = v:
    let
      colors = {
        accent = v.accent;
        bright_fg = v.fg;
        # fgSubtle would be 4.1:1 on the light bg; fgDim stays above 4.5 in both
        fg = v.fgDim;
        green = v.green;
        yellow = v.yellow;
        red = v.red;
      };
    in
    lib.concatStrings (lib.mapAttrsToList (k: c: ''${k} = "${hash c}"'' + "\n") colors);
in
{
  home.packages = [ pkgs.cliamp ];

  # only read, never written, so unlike config.toml these can be store symlinks
  xdg.configFile."cliamp/themes/frost-light.toml".text = cliampTheme frost.light;
  xdg.configFile."cliamp/themes/frost-dark.toml".text = cliampTheme frost.dark;
  xdg.configFile."cliamp/themes/frost-eink.toml".text = cliampTheme frost.eink;

  # cliamp rewrites config.toml itself (theme on every exit, shuffle/repeat/eq on change),
  # so a store symlink would break: seed it once and let cliamp own it afterwards
  home.activation.cliampConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="${config.xdg.configHome}/cliamp/config.toml"
    if [ ! -e "$cfg" ]; then
      run install -D -m 600 ${seed} "$cfg"
    fi
  '';
}
