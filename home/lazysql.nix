{ config, lib, pkgs, frost, scheme, theme, ... }:

let
  inherit (frost) hash;

  # lazysql has a single [theme], so unlike helix it gets only the live variant
  v = theme;

  # lazysql takes only opaque #rrggbb, so a tint is hue c laid over bg —
  # hunk's blend, at hunk's content strengths
  tint = c:
    let
      t = if scheme == "light" then 0.18 else 0.28;
      channel = s: i: lib.fromHexString (builtins.substring i 2 s);
      mix = i: builtins.floor (channel c i * t + channel v.bg i * (1 - t) + 0.5);
      hex2 = n: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString n));
    in
    hash (lib.concatMapStrings (i: hex2 (mix i)) [ 0 2 4 ]);

  # lazysql gives each colour several jobs, so the picks follow its heaviest one:
  # - PrimaryText is all text and also the focused pane's border.
  # - InverseText is the unfocused border, the italic NULL, and the fill of form
  #   fields. fgSubtle is the one grey that recedes yet still carries bg text.
  # - SecondaryText is the selection fill and the hotkey colour, so the lavender
  #   accent carries both, as in btop and cliamp, with bg text on it.
  # Grid lines and dividers recede to the border grey. SQL follows helix's
  # earl_grey picks: keywords lavender, types yellow, comments dim, the rest
  # plain. NULL in the JSON viewer matches NULL in the table. Pending edits tint
  # the row in hunk's colours: green insert, red delete, lavender change, with
  # blue for marked rows, as btop uses blue for "followed".
  colors = {
    # a real colour, not "default": the cell editor draws its text in it, and
    # "default" there is foot's foreground, invisible on its PrimaryText field.
    # foot's alpha-mode = "matching" still frosts cells painted exactly bg.
    PrimitiveBackground = hash v.bg;
    ContrastBackground = hash v.bgInset;
    MoreContrastBackground = hash v.sel;
    Border = hash v.border;
    Title = hash v.fg;
    Graphics = hash v.border;
    PrimaryText = hash v.fg;
    SecondaryText = hash v.accent;
    TertiaryText = hash v.fgDim;
    InverseText = hash v.fgSubtle;
    ContrastSecondaryText = hash v.bg;

    SidebarTitleBorder = hash v.border;
    Error = hash v.red;
    ReadOnly = hash v.yellow;

    TableChange = tint v.accent;
    TableInsert = tint v.green;
    TableDelete = tint v.red;
    TableMarked = tint v.blue;

    EditorSelection = hash v.selStrong;
    EditorStatusBarBackground = hash v.bg;
    EditorStatusBarText = hash v.fgDim;

    # helix's ui.menu
    AutocompleteBackground = hash v.bgInset;
    AutocompleteText = hash v.fg;
    AutocompleteSelected = hash v.sel;
    AutocompleteDescription = hash v.fgDim;
    AutocompleteSeparator = hash v.fgSubtle;

    SQLKeyword = hash v.accent;
    SQLString = hash v.fg;
    SQLNumber = hash v.fg;
    SQLComment = hash v.fgDim;
    SQLFunction = hash v.fg;
    SQLOperator = hash v.fg;
    SQLType = hash v.yellow;
    SQLBoolean = hash v.fg;
    SQLParameter = hash v.fg;

    JSONKey = hash v.fg;
    JSONString = hash v.fg;
    JSONBoolean = hash v.fg;
    JSONNull = hash v.fgSubtle;
    JSONNumber = hash v.fg;
  };

  themeFile = (pkgs.formats.toml { }).generate "lazysql-theme.toml" {
    theme.Colors = colors;
  };
in
{
  home.packages = [ pkgs.lazysql ];

  # lazysql rewrites config.toml itself (on every saved connection and theme
  # pick), and the file holds connection URLs, so a store symlink would break
  # it. Instead each switch drops whatever [theme] tables the file has and
  # appends ours: the connections stay, and the theme follows `variant`.
  # A preset picked inside lazysql lasts until the next switch.
  home.activation.lazysqlTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="${config.xdg.configHome}/lazysql/config.toml"
    merged="$(mktemp)"
    if [ -e "$cfg" ]; then
      printf '%s\n\n' "$(${pkgs.gawk}/bin/awk '
        /^[[:space:]]*\[/ { skip = $0 ~ /^[[:space:]]*\[[[:space:]]*theme[[:space:]]*[].]/ }
        !skip
      ' "$cfg")" > "$merged"
    fi
    cat ${themeFile} >> "$merged"
    run install -D -m 600 "$merged" "$cfg"
    rm "$merged"
  '';
}
