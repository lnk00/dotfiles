{ pkgs, ... }:

let
  # mango.nix runs the cliphist watcher; this picks an old entry back onto the clipboard
  clipboard-pick = pkgs.writeShellApplication {
    name = "clipboard-pick";
    runtimeInputs = with pkgs; [ cliphist fuzzel wl-clipboard ];
    text = ''
      # fuzzel exits non-zero on Esc; show the preview column, keep the id for decode
      entry=$(cliphist list | fuzzel --dmenu --with-nth 2 --prompt "clip ") || exit 0
      cliphist decode <<< "$entry" | wl-copy
    '';
  };
in
{
  home.packages = [ pkgs.cliphist clipboard-pick ];
}
