{ ... }:

{
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      editor = {
        true-color = true;
        color-modes = true;
        indent-guides.render = true;
        # capped at half the window height, so this keeps the cursor on the middle line
        scrolloff = 999;
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
      # a j not followed by k is still typed, just held until the next key
      keys.insert.j.k = "normal_mode";
    };
  };
}
