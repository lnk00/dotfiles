{ config, lib, pkgs, theme, ... }:

let
  # the card sits off the screen edges like a window: mango's outer gaps
  inherit (config.wayland.windowManager.mango.settings) gap_outer_horizontal gap_outer_vertical;
in
{
  # supervised by systemd: a bare autostart clock died silently twice and stayed gone
  systemd.user.services.quickshell = {
    Unit.PartOf = [ "mango-session.target" ];
    Service.Restart = lib.mkForce "always";
  };

  # time over date, top right, shown for 3s on SUPER+c (mango.nix)
  programs.quickshell = {
    enable = true;
    activeConfig = "clock";
    # mango starts mango-session.target itself, even with its HM systemd.enable off
    systemd = {
      enable = true;
      target = "mango-session.target";
    };
    configs.clock = pkgs.writeTextDir "shell.qml" ''
      import QtQuick
      import Quickshell
      import Quickshell.Io
      import Quickshell.Wayland

      ShellRoot {
        SystemClock { id: clock; precision: SystemClock.Minutes }

        // quickshell ipc -c clock call clock peek
        IpcHandler {
          target: "clock"
          // pressing again while it shows restarts the 3s
          function peek(): void { card.visible = true; hide.restart() }
        }
        Timer { id: hide; interval: 3000; onTriggered: card.visible = false }

        // overlay: above windows, even fullscreen ones; click-through
        PanelWindow {
          id: card
          // the time's pixel size; the date, padding and spacing scale with it
          readonly property int size: 96

          visible: false
          anchors { top: true; right: true }
          margins { top: ${toString gap_outer_vertical}; right: ${toString gap_outer_horizontal} }
          exclusionMode: ExclusionMode.Ignore
          WlrLayershell.layer: WlrLayer.Overlay
          WlrLayershell.namespace: "clock"
          color: "transparent"
          mask: Region {}
          implicitWidth: face.implicitWidth + Math.round(size * 0.38)
          implicitHeight: face.implicitHeight + Math.round(size * 0.33)

          // translucent, so mango's layer blur frosts whatever is under it, like fuzzel and mako
          Rectangle {
            anchors.fill: parent
            radius: 8
            // same as mango's window borders
            border { width: 2; color: "#cc${theme.border}" }
            color: "#${theme.glass}${theme.bg}"

            Column {
              id: face
              anchors.centerIn: parent
              spacing: Math.round(card.size * 0.12)

              // the negative paddings trim the font's line box down to the glyphs
              Text {
                anchors.right: parent.right
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: "#${theme.fg}"
                font { family: "JetBrainsMono Nerd Font"; weight: Font.Thin; pixelSize: card.size }
                topPadding: Math.round(-0.24 * font.pixelSize)
                bottomPadding: Math.round(-0.3 * font.pixelSize)
              }
              Text {
                anchors.right: parent.right
                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
                // halfway from fgDim to fg: set apart from the time, but not by much
                color: Qt.tint("#${theme.fgDim}", "#80${theme.fg}")
                font { family: "JetBrainsMono Nerd Font"; weight: Font.Light; pixelSize: Math.round(card.size / 5) }
                topPadding: Math.round(-0.25 * font.pixelSize)
              }
            }
          }
        }
      }
    '';
  };
}
