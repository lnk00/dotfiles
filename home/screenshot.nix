{ pkgs, theme, ... }:

let
  # copies to the clipboard and keeps a dated png in ~/Pictures/Screenshots
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [ grim slurp wl-clipboard coreutils libnotify ];
    text = ''
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

      case "''${1:-full}" in
        full) grim "$file" ;;
        region)
          # slurp exits non-zero on Esc
          geom=$(slurp -w 2 -c '#${theme.accent}ff' -b '#${theme.bg}55' -s '#00000000') || exit 0
          grim -g "$geom" "$file"
          ;;
        *)
          echo "usage: screenshot [full|region]" >&2
          exit 1
          ;;
      esac

      wl-copy --type image/png < "$file"
      # the shot itself is the icon, so mako shows a thumbnail
      notify-send -a screenshot -i "$file" -t 3000 "Screenshot" "Saved and copied"
    '';
  };
in
{
  home.packages = [ screenshot ];
}
