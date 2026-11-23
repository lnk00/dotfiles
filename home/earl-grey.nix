# Helix's earl_grey palette ("#rrggbb" by name: chaotica, deepspace, earl, …), read from
# the theme file Helix itself loads, so foot and Jay follow Helix when it changes.
# nixpkgs copies the themes straight from the source, so evaluating fetches it if the
# weekly gc took it
pkgs:
(builtins.fromTOML (builtins.readFile "${pkgs.helix-unwrapped.src}/runtime/themes/earl_grey.toml")).palette
