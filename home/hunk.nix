{ lib, hunk, frost, variant, ... }:

let
  inherit (frost) hash;

  # hunk takes only opaque #rrggbb, so a tint is hue c laid over bg at strength t
  tint = t: c: bg:
    let
      channel = s: i: lib.fromHexString (builtins.substring i 2 s);
      mix = i: builtins.floor (channel c i * t + channel bg i * (1 - t) + 0.5);
      hex2 = n: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString n));
    in
    hash (lib.concatMapStrings (i: hex2 (mix i)) [ 0 2 4 ]);

  # Every selector github-*-default colours, verbatim, plus the two grammar
  # roots. A custom theme can only add rules on top of its base, and a more
  # specific base rule beats a broader override, so each one is restated here
  # at equal specificity: that is what lets earl_grey's restraint win. All of
  # these are plain text unless picked out in `syntax` below.
  githubScopes = [
    "source" "text"
    "comment" "punctuation.definition.comment" "string.comment"
    "constant" "constant.character" "constant.other.placeholder"
    "entity" "entity.name" "entity.name.constant" "entity.name.function"
    "entity.name.tag" "support.class.component"
    "variable" "variable.other" "variable.other.constant" "variable.other.enummember"
    "variable.language" "variable.parameter.function"
    "meta.export.default" "meta.definition.variable" "meta.jsx.children" "meta.block"
    "meta.tag.attributes" "meta.object.member" "meta.embedded.expression"
    "meta.property-name" "meta.module-reference" "meta.separator" "meta.output"
    "keyword" "storage" "storage.type"
    "storage.modifier.package" "storage.modifier.import" "storage.type.java"
    "string" "string punctuation.section.embedded source" "string variable"
    "punctuation.section.embedded"
    "source.regexp" "string.regexp" "string.regexp.character-class"
    "string.regexp constant.character.escape" "string.regexp source.ruby.embedded"
    "string.regexp string.regexp.arbitrary-repitition"
    "support" "support.constant" "support.variable" "support.type.property-name.json"
    "constant.other.reference.link" "string.other.link"
    "markup.heading" "markup.heading entity.name" "markup.quote" "markup.italic" "markup.bold"
    "markup.inline.raw" "punctuation.definition.list.begin.markdown"
    "markup.inserted" "meta.diff.header.to-file" "punctuation.definition.inserted"
    "markup.deleted" "meta.diff.header.from-file" "punctuation.definition.deleted"
    "markup.changed" "punctuation.definition.changed" "markup.ignored" "markup.untracked"
    "meta.diff.range" "meta.diff.header"
    "invalid.broken" "invalid.deprecated" "invalid.illegal" "invalid.unimplemented"
    "message.error" "carriage-return"
    "brackethighlighter.tag" "brackethighlighter.curly" "brackethighlighter.round"
    "brackethighlighter.square" "brackethighlighter.angle" "brackethighlighter.quote"
    "brackethighlighter.unmatched"
  ];

  # helix's earl_grey picks: keywords lavender, types yellow, comments dim.
  # Functions stay plain because hunk's scopes carry colour only, no bold.
  syntax = v:
    let
      paint = c: scopes: lib.genAttrs scopes (_: hash c);
    in
    paint v.fg githubScopes
    // paint v.fgDim [
      "comment" "punctuation.definition.comment" "string.comment"
      "markup.inline.raw" "markup.changed" "punctuation.definition.changed"
      "markup.ignored" "markup.untracked" "meta.diff.range" "meta.diff.header"
    ]
    // paint v.accent [ "keyword" "storage" "storage.type" ]
    // paint v.yellow [
      "entity.name.type" "entity.name.class" "entity.other.inherited-class"
      "support.type" "support.class"
    ]
    // paint v.green [ "markup.inserted" "meta.diff.header.to-file" "punctuation.definition.inserted" ]
    // paint v.red [
      "markup.deleted" "meta.diff.header.from-file" "punctuation.definition.deleted"
      "invalid.broken" "invalid.deprecated" "invalid.illegal" "invalid.unimplemented"
      "message.error" "brackethighlighter.unmatched"
    ];

  # A custom theme inherits every key it leaves out from its GitHub base, so
  # all of them are set. Tint strengths are the ones hunk derives its own
  # themes with, softer on a pale surface.
  hunkTheme = name:
    let
      v = frost.${name};
      light = name == "light";
      row = tint (if light then 0.12 else 0.2);
      content = tint (if light then 0.18 else 0.28);
      selected = tint (if light then 0.18 else 0.25);
    in
    {
      base = "github-${name}-default";
      background = hash v.bg;
      contextBg = hash v.bg;
      contextContentBg = hash v.bg;
      lineNumberBg = hash v.bg;
      panel = hash v.bgAlt;
      panelAlt = hash v.bgInset;
      border = hash v.border;
      text = hash v.fg;
      muted = hash v.fgDim;
      lineNumberFg = hash v.fgSubtle;
      accent = hash v.accent;
      accentMuted = selected v.accent v.bg;
      selectedHunk = selected v.accent v.bg;
      movedAddedBg = row v.accent v.bg;
      movedRemovedBg = row v.accent v.bg;
      addedBg = row v.green v.bg;
      addedContentBg = content v.green v.bg;
      removedBg = row v.red v.bg;
      removedContentBg = content v.red v.bg;
      addedSignColor = hash v.green;
      removedSignColor = hash v.red;
      badgeAdded = hash v.green;
      badgeRemoved = hash v.red;
      badgeNeutral = hash v.fgDim;
      fileNew = hash v.green;
      fileUntracked = hash v.green;
      fileDeleted = hash v.red;
      fileModified = hash v.accent;
      fileRenamed = hash v.accent;
      noteBorder = hash v.accent;
      noteBackground = hash v.bgAlt;
      noteTitleBackground = hash v.bgAlt;
      noteTitleText = hash v.fg;
      syntax_scopes = syntax v;
    };
in
{
  imports = [ hunk.homeManagerModules.default ];

  programs.hunk = {
    enable = true;
    settings = {
      # one column of +/- rows, never side by side
      mode = "unified";
      # like helix, follows `variant` rather than foot's runtime toggle
      theme = "frost-${variant}";
      # like helix's bg-less ui.background: foot's translucency shows through
      transparent_background = true;
      themes.frost-light = hunkTheme "light";
      themes.frost-dark = hunkTheme "dark";
    };
  };
}
