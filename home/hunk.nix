{ hunk, ... }:

{
  imports = [ hunk.homeManagerModules.default ];

  programs.hunk = {
    enable = true;
    # one column of +/- rows, never side by side
    settings.mode = "unified";
  };
}
