{ frost, variant, ... }:

let
  inherit (frost) hash;

  # ui.background deliberately carries no bg so the terminal's translucency —
  # and therefore mango's blur — shows through the editor.
  helixTheme = v: {
    "ui.background" = { fg = hash v.fg; };
    "ui.text" = { fg = hash v.fg; };
    "ui.text.focus" = { fg = hash v.fg; modifiers = [ "bold" ]; };
    "ui.window" = { fg = hash v.border; };
    "ui.cursor" = { fg = hash v.bg; bg = hash v.accent; };
    "ui.cursor.primary" = { fg = hash v.bg; bg = hash v.accent; };
    "ui.cursor.match" = { bg = hash v.sel; modifiers = [ "bold" ]; };
    "ui.selection" = { bg = hash v.sel; };
    "ui.selection.primary" = { fg = hash v.brWhite; bg = hash v.selStrong; };
    "ui.linenr" = { fg = hash v.fgSubtle; };
    "ui.linenr.selected" = { fg = hash v.accent; modifiers = [ "bold" ]; };
    "ui.gutter" = { };
    "ui.statusline" = { fg = hash v.fg; };
    "ui.statusline.inactive" = { fg = hash v.fgDim; };
    "ui.statusline.normal" = { fg = hash v.bg; bg = hash v.blue; };
    "ui.statusline.insert" = { fg = hash v.bg; bg = hash v.accent; };
    "ui.statusline.select" = { fg = hash v.bg; bg = hash v.magenta; };
    "ui.popup" = { fg = hash v.fg; bg = hash v.bgInset; };
    "ui.help" = { fg = hash v.fg; bg = hash v.bgInset; };
    "ui.menu" = { fg = hash v.fg; bg = hash v.bgInset; };
    "ui.menu.selected" = { fg = hash v.fg; bg = hash v.sel; };
    "ui.virtual.ruler" = { bg = hash v.bgAlt; };
    "ui.virtual.jump-label" = { fg = hash v.magenta; modifiers = [ "bold" ]; };
    "ui.highlight" = { bg = hash v.bgInset; };
    "ui.virtual.whitespace" = { fg = hash v.fgFaint; };
    "ui.virtual.indent-guide" = { fg = hash v.fgFaint; };
    "ui.virtual.inlay-hint" = { fg = hash v.fgDim; };

    # earl_grey's restraint: structure only. Types, keywords and functions
    # carry the whole signal; comments recede with "dim"; everything else —
    # variables, strings, constants, punctuation, tags — stays plain text.
    "comment" = { modifiers = [ "dim" ]; };
    "keyword" = { fg = hash v.accent; };
    "type" = { fg = hash v.yellow; };
    "function" = { modifiers = [ "bold" ]; };

    "markup.heading" = { modifiers = [ "bold" ]; };
    "markup.bold" = { modifiers = [ "bold" ]; };
    "markup.italic" = { modifiers = [ "italic" ]; };
    "markup.link.url" = { modifiers = [ "underlined" ]; };
    "markup.raw" = { fg = hash v.fgDim; };

    "diff.plus" = { fg = hash v.green; };
    "diff.minus" = { fg = hash v.red; };
    "diff.delta" = { fg = hash v.fgDim; };

    "error" = { fg = hash v.red; };
    "warning" = { fg = hash v.yellow; };
    "info" = { fg = hash v.fgDim; };
    "hint" = { fg = hash v.blue; };
    "diagnostic.error" = { underline = { color = hash v.red; style = "curl"; }; };
    "diagnostic.warning" = { underline = { color = hash v.yellow; style = "curl"; }; };
    "diagnostic.info" = { underline = { color = hash v.fgDim; style = "curl"; }; };
    "diagnostic.hint" = { underline = { color = hash v.blue; style = "curl"; }; };
  };
in
{
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "frost-${variant}";
      editor = {
        true-color = true;
        color-modes = true;
        indent-guides.render = true;
        statusline.mode = { normal = "NORMAL"; insert = "INSERT"; select = "SELECT"; };
      };
      # space-leader stays on the thumb on the 3w6; x = "execute".
      keys.normal.space = {
        # default recipe in the background; output pops up when it exits
        x = ":sh just";
        # pick a recipe with fzf and watch it live in a tiled foot window
        X = ":sh foot -H just --choose";
        # replaces the space-w window menu; ctrl-w still opens it
        w = ":write";
        q = ":quit";
      };
      # replaces goto window center
      keys.normal.g.c = ":buffer-close";
    };
    themes = {
      frost-light = helixTheme frost.light;
      frost-dark = helixTheme frost.dark;
    };
  };
}
