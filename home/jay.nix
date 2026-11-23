{ config, lib, pkgs, ... }:

let
  jay = lib.getExe pkgs.jay;
  eg = import ./earl-grey.nix pkgs;
  coreutils = "${pkgs.coreutils}/bin";

  # new foot in the cwd of the focused foot's shell, else $HOME
  footHere = pkgs.writeShellApplication {
    name = "foot-here";
    runtimeInputs = with pkgs; [ foot jq procps coreutils ];
    text = ''
      dir=$HOME
      pid=$(${jay} --json tree query match-windows -e 'focused = true app-id = "foot"' \
        | jq -r '.client.pid // empty' | head -n 1) || true
      if [ -n "$pid" ] && child=$(pgrep -nP "$pid"); then
        dir=$(readlink "/proc/$child/cwd") || dir=$HOME
      fi
      [ -d "$dir" ] || dir=$HOME
      exec foot --working-directory="$dir"
    '';
  };

  # pick a window by app id and title, focus it
  windowPick = pkgs.writeShellApplication {
    name = "window-pick";
    runtimeInputs = with pkgs; [ fuzzel wlrctl ];
    text = ''
      # wlrctl lists "app_id: title" and matches both exactly; fuzzel exits non-zero on Esc
      entry=$(wlrctl toplevel list | fuzzel --dmenu --prompt "window ") || exit 0
      wlrctl toplevel focus "app_id:''${entry%%: *}" "title:''${entry#*: }"
    '';
  };

  # start Zen unless it already has a window; the windows rule puts it on the overlay
  zenLaunch = pkgs.writeShellApplication {
    name = "zen-launch";
    text = ''
      # the query prints nothing (and exits 0) when no window matches
      [ -n "$(${jay} tree query match-windows -e 'app-id = "zen-beta"')" ] || exec zen-beta
    '';
  };

  exec = cmd: { type = "exec"; exec = cmd; };

  # SUPER+1..5 shows a workspace, SUPER+SHIFT+1..5 sends the focused window there
  workspaceKeys = lib.listToAttrs (lib.concatMap
    (i:
      let n = toString i; in [
        (lib.nameValuePair "logo-${n}" { type = "show-workspace"; name = n; })
        (lib.nameValuePair "logo-shift-${n}" { type = "move-to-workspace"; name = n; })
      ])
    (lib.range 1 5));

  # Jay switches VTs itself; without these ctrl-alt-Fn does nothing
  vts = lib.listToAttrs (map
    (i: lib.nameValuePair "ctrl-alt-F${toString i}" { type = "switch-to-vt"; num = i; })
    (lib.range 1 12));

  # A config file replaces Jay's built-in one entirely, so everything is spelled out
  settings = {
    # HM swaps the symlink on every switch
    auto-reload = true;
    repeat-rate = { rate = 75; delay = 200; };
    # focus follows clicks only
    focus-follows-mouse = false;
    # the screen never blanks
    idle.minutes = 0;
    cursor-size = config.home.pointerCursor.size;

    # card1, the AMD iGPU, is the boot VGA device, but the monitor hangs off the 4060 Ti
    render-device.pci-vendor = 4318; # 0x10de, NVIDIA

    # Helix's earl_grey, each colour taken from the Helix element it stands in for.
    # Screen-shared and attention titles keep Jay's dark red and purple: the palette has
    # nothing that dark in those hues, and the light title text needs a dark background
    theme = {
      # the desktop, which has no wallpaper (ui.background)
      bg-color = eg.chaotica;
      # the bar is a statusline (ui.statusline)
      bar-bg-color = eg.deepspace;
      # white like the workspace labels next to it (ui.text.focus)
      bar-status-text-color = eg.snow;
      # where hx keeps its statusline
      bar-position = "bottom";
      # titles are a menu: the focused one ui.menu.selected, the rest ui.statusline.inactive
      focused-title-bg-color = eg.lacquer;
      focused-title-text-color = eg.snow;
      unfocused-title-bg-color = eg.deepspace;
      unfocused-title-text-color = eg.grey;
      # the visible tab of an unfocused container: ui.highlight, ui.text
      focused-inactive-title-bg-color = eg.space;
      focused-inactive-title-text-color = eg.silver;
      # split lines (ui.window)
      separator-color = eg.space;
      border-color = eg.space;
      # drop targets and picked windows, see-through like Jay's default
      highlight-color = "${eg.earl}7f";
    };

    # the date and time on the right of the bar, like the shell's `now`; a line a minute,
    # on the minute
    status = {
      format = "plain";
      exec.shell = ''
        while :; do
          ${coreutils}/date '+%A %-d %B %Y, %H:%M'
          ${coreutils}/sleep $((60 - $(${coreutils}/date +%-S)))
        done
      '';
    };

    # the browser lives on an overlay, a workspace drawn over the normal one, so the
    # normal workspaces hold only terminals. Every Zen window goes there, floating,
    # centred at 16:10 like a MacBook Air
    workspaces.browser.type = "overlay";
    windows = [
      {
        match.app-id = "zen-beta";
        initial-tile-state = "floating";
        initial-floating-size = { width = 1920; height = 1200; };
      }
      # Zen opens straight into the overlay when SUPER+B showed it first; started any
      # other way (fuzzel, a link) it lands on a normal workspace and is moved over.
      # The overlay is shown first, as a hidden one has no output and squashes the
      # window to 8x18. The move waits a main-loop iteration (just-mapped = false):
      # until then Jay hasn't recorded the 1920x1200 and moves it at half the screen
      {
        match = { app-id = "zen-beta"; just-mapped = false; };
        action = [
          { type = "show-overlay"; name = "browser"; }
          { type = "move-to-workspace"; name = "browser"; }
        ];
      }
    ];

    on-graphics-initialized = [
      (exec [ "${pkgs.wl-clipboard}/bin/wl-paste" "--watch" "${pkgs.cliphist}/bin/cliphist" "store" ])
    ];

    shortcuts = {
      # new windows open in the browser overlay while it's up, so it goes away first
      logo-t = [
        { type = "hide-overlay"; name = "browser"; }
        (exec "${footHere}/bin/foot-here")
      ];
      logo-d = "close";
      logo-f = "toggle-fullscreen";
      # shows or hides the browser overlay, and starts Zen if it isn't running
      logo-b = [
        { type = "toggle-overlay"; name = "browser"; }
        (exec "${zenLaunch}/bin/zen-launch")
      ];
      logo-m = "quit";
      logo-h = "focus-left";
      logo-j = "focus-down";
      logo-k = "focus-up";
      logo-l = "focus-right";
      logo-shift-h = "move-left";
      logo-shift-j = "move-down";
      logo-shift-k = "move-up";
      logo-shift-l = "move-right";
      # new windows go beside the focused one; this stacks them instead (and back)
      logo-e = "toggle-split";
      # tabs: G shows one window of the container at a time (or all again), Y/O step through it
      logo-g = "toggle-mono";
      logo-y = "focus-left";
      logo-o = "focus-right";
      logo-s = exec [ "screenshot" "full" ];
      logo-shift-s = exec [ "screenshot" "region" ];
      logo-space = exec "fuzzel";
      logo-v = exec "clipboard-pick";
      logo-Tab = exec "${windowPick}/bin/window-pick";
      # dictation (voxtype.nix): hold SUPER+R and speak, the text is typed on release.
      # voxtype reads that chord from the keyboard itself; it's bound only so apps never
      # see it. SUPER+W starts and stops a hands-free take
      logo-r = "consume";
      logo-w = exec [ "voxtype" "record" "toggle" ];
    } // workspaceKeys // vts;

    # width in steps of 5% of the 2560px screen, split between both edges, held to repeat
    complex-shortcuts = {
      logo-ctrl-h = { action = { type = "resize"; dx1 = 64; dx2 = -64; }; repeat = true; };
      logo-ctrl-l = { action = { type = "resize"; dx1 = -64; dx2 = 64; }; repeat = true; };
    };

    # touchpads (the Magic Trackpad): slower scrolling, and a press (not a tap) to click
    inputs = [
      {
        match.is-gesture = true;
        px-scroll-multiplier = 0.5;
        tap-enabled = false;
      }
    ];

    # Jay hides privileged protocols from clients unless a rule grants them; without one
    # these tools don't error, they hang or do nothing. A matching rule replaces the
    # default grant (layer-shell), so slurp gets it back explicitly
    clients = [
      # cliphist's watcher, clipboard-pick, helix and Claude Code. nixpkgs wraps wl-copy,
      # and the kernel cuts .wl-copy-wrapped to 15 characters
      {
        match.any = [ { comm = "wl-copy"; } { comm = ".wl-copy-wrappe"; } { comm = "wl-paste"; } ];
        capabilities = [ "data-control" ];
      }
      # screenshot.nix
      {
        match.any = [ { comm = "grim"; } { comm = "slurp"; } ];
        capabilities = [ "screencopy" "layer-shell" ];
      }
      # voxtype types its text with wtype
      {
        match.comm = "wtype";
        capabilities = [ "virtual-keyboard" ];
      }
      # window-pick
      {
        match.comm = "wlrctl";
        capabilities = [ "foreign-toplevel-manager" ];
      }
      # screen sharing (configuration.nix): it captures through ext-image-copy-capture and
      # lists windows through ext-foreign-toplevel-list. nixpkgs wraps it
      {
        match.exe-regex = "/\\.?xdg-desktop-portal-wlr(-wrapped)?$";
        capabilities = [ "screencopy" "foreign-toplevel-list" ];
      }
    ];
  };
in
{
  xdg.configFile."jay/config.toml".source = (pkgs.formats.toml { }).generate "jay-config.toml" settings;

  # Jay draws no pointer without a cursor theme, and the system ships none; it falls back
  # to ~/.icons/default, which this links to Adwaita
  home.pointerCursor = {
    enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
  };
}
