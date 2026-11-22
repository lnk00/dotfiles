{ config, lib, pkgs, hash, theme, ... }:

let
  v = theme;

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
  cliampTheme =
    let
      colors = {
        accent = v.accent;
        bright_fg = v.fg;
        # fgSubtle would be 4.1:1 on bg; fgDim stays above 4.5
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

  # only read, never written, so unlike config.toml it can be a store symlink
  xdg.configFile."cliamp/themes/frost-light.toml".text = cliampTheme;

  # cliamp rewrites config.toml itself (theme on every exit, shuffle/repeat/eq on change),
  # so a store symlink would break: seed it once and let cliamp own it afterwards
  home.activation.cliampConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="${config.xdg.configHome}/cliamp/config.toml"
    if [ ! -e "$cfg" ]; then
      run install -D -m 600 ${seed} "$cfg"
    fi
  '';
}
