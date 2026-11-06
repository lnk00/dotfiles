{ pkgs, ... }:

let
  # swaps swaybg at runtime and saves the choice; mango.nix's autostart restores it
  wallpaper = pkgs.writeShellApplication {
    name = "wallpaper";
    runtimeInputs = with pkgs; [ fuzzel findutils gnused coreutils procps util-linux ];
    text = ''
      dir=${../wallpapers}
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"

      case "''${1:-}" in
        --restore) name=$(cat "$state" 2>/dev/null) || name=alone-cloud_dark ;;
        "")
          # fuzzel exits non-zero on Esc
          name=$(find "$dir" -type f -printf '%f\n' | sed 's/\.[^.]*$//' | sort | fuzzel --dmenu --prompt "wallpaper ") || exit 0
          ;;
        *) name=$1 ;;
      esac

      # a name from ../wallpapers (no extension), or any image path
      if [ -f "$name" ]; then
        name=$(realpath "$name")
        file=$name
      else
        file=$(find "$dir" -type f -name "$name.*" -print -quit)
        if [ -z "$file" ]; then
          echo "wallpaper: no '$name' in /etc/nixos/wallpapers" >&2
          exit 1
        fi
      fi

      mkdir -p "$(dirname "$state")"
      echo "$name" > "$state"

      # the wrapper keeps the full store path as argv0, so match on that
      mapfile -t old < <(pgrep -f '^/nix/store/[^ ]*/bin/swaybg ')
      setsid -f ${pkgs.swaybg}/bin/swaybg -m fill -i "$file" >/dev/null 2>&1
      if [ ''${#old[@]} -gt 0 ]; then
        # let the new one draw first, so the swap doesn't flash root_color
        sleep 0.3
        kill "''${old[@]}"
      fi
    '';
  };
in
{
  home.packages = [ wallpaper ];
}
