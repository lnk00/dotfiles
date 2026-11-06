{ lib, pkgs, theme, ... }:

{
  # supervised by systemd: a bare autostart clock died silently twice and stayed gone
  systemd.user.services.quickshell = {
    Unit.PartOf = [ "mango-session.target" ];
    Service.Restart = lib.mkForce "always";
  };

  # time over date, centered on a blurred screen, for about 2s on SUPER+c (mango.nix)
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
      import QtQuick.Effects
      import Quickshell
      import Quickshell.Io
      import Quickshell.Wayland

      ShellRoot {
        SystemClock { id: clock; precision: SystemClock.Minutes }

        // quickshell ipc -c clock call clock peek
        IpcHandler {
          target: "clock"
          // pressing again while it shows hides it early
          function peek(): void { if (veil.visible) veil.dismiss(); else veil.visible = true }
        }

        // overlay over the whole output, even fullscreen windows. mango's own layer blur and
        // fade can't animate the blur (and its fade starts at half opacity), so the layer has
        // no_blur and no_animation, and this blurs and fades a still of the screen itself
        PanelWindow {
          id: veil
          // 0: the screen as it is; 1: blurred and tinted, with the clock on top
          property real progress: 0
          // the time's pixel size; the date and spacing scale with it
          readonly property int size: 240
          // the blur needs real pixels past the screen's edges, or they fade out
          readonly property int bleed: 64

          function dismiss(): void { hold.stop(); fadeIn.stop(); fadeOut.start() }

          visible: false
          anchors { top: true; bottom: true; left: true; right: true }
          exclusionMode: ExclusionMode.Ignore
          WlrLayershell.layer: WlrLayer.Overlay
          WlrLayershell.namespace: "clock"
          color: "transparent"

          // a fresh still on every show; nothing is drawn until it arrives, so it doesn't capture itself
          Loader {
            id: still
            active: veil.visible
            sourceComponent: ScreencopyView {
              visible: false
              width: veil.width
              height: veil.height
              captureSource: veil.screen
              onHasContentChanged: if (hasContent) fadeIn.start()
            }
          }
          // roughly mango's blur_params, so it matches fuzzel and mako
          MultiEffect {
            x: -veil.bleed
            y: -veil.bleed
            width: veil.width + 2 * veil.bleed
            height: veil.height + 2 * veil.bleed
            source: still.item
            opacity: veil.progress
            autoPaddingEnabled: false
            blurEnabled: true
            blur: veil.progress
            blurMax: 64
            brightness: 0.05
            contrast: -0.1
            saturation: -0.15
          }
          // lighter than theme.glass: the big text stays readable and more of the blur shows
          Rectangle { anchors.fill: parent; color: "#99${theme.bg}"; opacity: veil.progress }

          Column {
            anchors.centerIn: parent
            spacing: Math.round(veil.size * 0.12)
            opacity: veil.progress

            // the negative paddings trim the font's line box down to the glyphs
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Qt.formatDateTime(clock.date, "HH:mm")
              color: "#${theme.fg}"
              font { family: "JetBrainsMono Nerd Font"; weight: Font.Thin; pixelSize: veil.size }
              topPadding: Math.round(-0.24 * font.pixelSize)
              bottomPadding: Math.round(-0.3 * font.pixelSize)
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
              // halfway from fgDim to fg: set apart from the time, but not by much
              color: Qt.tint("#${theme.fgDim}", "#80${theme.fg}")
              font { family: "JetBrainsMono Nerd Font"; weight: Font.Light; pixelSize: Math.round(veil.size / 5) }
              topPadding: Math.round(-0.25 * font.pixelSize)
            }
          }

          // a click anywhere hides it, rather than landing on a window you can't see
          MouseArea { anchors.fill: parent; onClicked: veil.dismiss() }

          NumberAnimation { id: fadeIn; target: veil; property: "progress"; to: 1; duration: 250; easing.type: Easing.OutCubic; onFinished: hold.restart() }
          Timer { id: hold; interval: 1500; onTriggered: fadeOut.start() }
          NumberAnimation { id: fadeOut; target: veil; property: "progress"; to: 0; duration: 250; easing.type: Easing.InCubic; onFinished: veil.visible = false }
        }
      }
    '';
  };
}
