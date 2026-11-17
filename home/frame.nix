{ config, lib, pkgs, theme, ... }:

let
  # A frame round the screen, as wide and as coloured as the window borders and
  # laid exactly over them (gaps_out 0): it closes the box on the sides, where the
  # scroller cuts the neighbouring columns off and their borders go with them.
  # Four strips rather than one see-through screen-sized surface, so Hyprland has
  # next to nothing to blend.
  shell = pkgs.writeTextDir "shell.qml" ''
    import QtQuick
    import Quickshell
    import Quickshell.Wayland

    ShellRoot {
      component Edge: PanelWindow {
        // reserve nothing: the strip overlaps the window borders, it mustn't push them in
        exclusionMode: ExclusionMode.Ignore
        // above windows, so it shows over the cut-off columns
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "frame"
        color: "#${theme.fgSubtle}"
        implicitWidth: ${toString theme.borderWidth}
        implicitHeight: ${toString theme.borderWidth}
        // clicks fall through to the windows underneath
        mask: Region {}
      }

      Edge { anchors { top: true; left: true; right: true } }
      Edge { anchors { bottom: true; left: true; right: true } }
      Edge { anchors { left: true; top: true; bottom: true } }
      Edge { anchors { right: true; top: true; bottom: true } }
    }
  '';
in
{
  # its own quickshell, supervised like micrographics
  systemd.user.services.frame = {
    Unit = {
      Description = "Screen frame matching the window borders";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe config.programs.quickshell.package} --path ${shell}/shell.qml";
      Restart = "always";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
