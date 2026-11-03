{ pkgs, theme, ... }:

{
  # big time top right, date bottom right, on the wallpaper; mango.nix starts it and keeps it unblurred
  programs.quickshell = {
    enable = true;
    configs.clock = pkgs.writeTextDir "shell.qml" ''
      import QtQuick
      import Quickshell
      import Quickshell.Wayland

      ShellRoot {
        // bottom layer: above swaybg, below every window; click-through
        component Corner: PanelWindow {
          exclusionMode: ExclusionMode.Ignore
          WlrLayershell.layer: WlrLayer.Bottom
          WlrLayershell.namespace: "clock"
          color: "transparent"
          mask: Region {}
        }

        SystemClock { id: clock; precision: SystemClock.Minutes }

        Corner {
          anchors { top: true; right: true }
          margins { top: 32; right: 48 }
          implicitWidth: time.implicitWidth
          implicitHeight: time.implicitHeight

          Text {
            id: time
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: "#${theme.fg}"
            font { family: "JetBrainsMono Nerd Font"; weight: Font.Thin; pixelSize: 168 }
          }
        }

        Corner {
          anchors { bottom: true; right: true }
          margins { bottom: 32; right: 48 }
          implicitWidth: date.implicitWidth
          implicitHeight: date.implicitHeight

          Text {
            id: date
            text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
            color: "#${theme.fgDim}"
            font { family: "JetBrainsMono Nerd Font"; weight: Font.Light; pixelSize: 28 }
          }
        }
      }
    '';
  };
}
