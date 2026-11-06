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

  # time over date, top right on the wallpaper, on a frosted card so any wallpaper stays readable
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
      import Quickshell.Widgets

      ShellRoot {
        SystemClock { id: clock; precision: SystemClock.Minutes }

        // the image swaybg shows, as an absolute path; wallpaper.nix rewrites it on every switch
        FileView {
          id: wallpaper
          path: "${config.xdg.stateHome}/wallpaper"
          watchChanges: true
          onFileChanged: reload()
        }

        // bottom layer: above swaybg, below every window; click-through
        PanelWindow {
          id: card
          // the blur needs real pixels past the card's edges, or they fade out
          readonly property int bleed: 64
          // the time's pixel size; the date, padding and spacing scale with it
          readonly property int size: 96

          anchors { top: true; right: true }
          margins { top: ${toString gap_outer_vertical}; right: ${toString gap_outer_horizontal} }
          exclusionMode: ExclusionMode.Ignore
          WlrLayershell.layer: WlrLayer.Bottom
          WlrLayershell.namespace: "clock"
          color: "transparent"
          mask: Region {}
          implicitWidth: face.implicitWidth + Math.round(size * 0.38)
          implicitHeight: face.implicitHeight + Math.round(size * 0.33)

          // mango never blurs bottom-layer surfaces, so the card frosts its own crop of the wallpaper
          ClippingRectangle {
            anchors.fill: parent
            radius: 8
            contentUnderBorder: true
            // same as mango's window borders
            border { width: 2; color: "#cc${theme.border}" }
            color: "#${theme.bg}"

            // the whole output as swaybg -m fill draws it
            Image {
              id: wall
              visible: false
              width: card.screen.width
              height: card.screen.height
              sourceSize { width: card.screen.width; height: card.screen.height }
              fillMode: Image.PreserveAspectCrop
              source: wallpaper.text().trim()
            }
            // just the part under the card
            ShaderEffectSource {
              id: under
              visible: false
              sourceItem: wall
              sourceRect: Qt.rect(card.screen.width - card.margins.right - card.width - card.bleed,
                                  card.margins.top - card.bleed,
                                  card.width + 2 * card.bleed, card.height + 2 * card.bleed)
            }
            // roughly mango's blur_params, so it matches fuzzel and mako
            MultiEffect {
              x: -card.bleed
              y: -card.bleed
              width: card.width + 2 * card.bleed
              height: card.height + 2 * card.bleed
              source: under
              autoPaddingEnabled: false
              blurEnabled: true
              blur: 1
              blurMax: 64
              brightness: 0.05
              contrast: -0.1
              saturation: -0.15
            }
            // theme.glass: lighter tints go grey and unreadable on bright wallpapers
            Rectangle { anchors.fill: parent; color: "#${theme.glass}${theme.bg}" }

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
