{ config, lib, pkgs, hash, theme, ... }:

let
  # the ONNX build: plain voxtype has Whisper only, and Whisper is too slow on CPU while the
  # 4060 Ti is on nouveau (no CUDA)
  voxtype = pkgs.voxtype-onnx;

  # Quickshell's colour parser reads #rrggbbaa as Qt's #aarrggbb, so translucent colours go
  # as rgba()
  rgba = c: a:
    let channel = i: toString (lib.fromHexString (builtins.substring i 2 c));
    in "rgba(${channel 0}, ${channel 2}, ${channel 4}, ${toString a})";

  # The recording card. The package ships its launcher but not the QML, which stays in the
  # source; Theme.qml hardcodes 12px corners, so it takes the theme's radius here
  osdQml = pkgs.runCommand "voxtype-osd-qml" { } ''
    cp -r ${voxtype.src}/quickshell $out
    chmod -R u+w $out
    substituteInPlace $out/voxtype-shared/Theme.qml \
      --replace-fail "property int cornerRadius: 12" "property int cornerRadius: ${toString theme.radius}"
  '';

  # dressed like mako: glass bg, the window borders' colour a little translucent, no glow.
  # The lavender accent carries the mic and waveform, the hues keep their meaning in the meter
  osdStyle = pkgs.writeTextDir "voxtype-osd.toml" ''
    name = "frost"
    version = "1"
    description = "theme.nix's palette"
    palette = "package"

    [colors]
    accent = "${hash theme.accent}"
    background = "${rgba theme.bg theme.termAlpha}"
    surface = "${hash theme.bgInset}"
    foreground = "${hash theme.fg}"
    muted = "${hash theme.fgSubtle}"
    success = "${hash theme.green}"
    warning = "${hash theme.yellow}"
    error = "${hash theme.red}"
    recording = "${hash theme.accent}"
    transcribing = "${hash theme.yellow}"
    idle = "${hash theme.fgSubtle}"

    [frame]
    background = "background"
    border = "${rgba theme.border 0.8}"
    glow = false
    halo = false
  '';
in
{
  home.packages = [ voxtype ];

  # Parakeet v3 is multilingual (fr/es/en, detected per take) and transcribes 11s of speech
  # in ~0.4s on the 7600X. Its model lives outside the store, fetched once with
  #   voxtype setup --download --model parakeet-tdt-0.6b-v3
  # It stays loaded (~2.6 GB) so a take never waits on a load. int8 was no faster here.
  xdg.configFile."voxtype/config.toml".text = ''
    engine = "parakeet"

    # SUPER+R, held to talk, read straight from the keyboards: a Hyprland release bind misses
    # R when SUPER comes up first, while voxtype ends the take on R's release whatever is
    # still held. R goes by its kernel keycode (letters have no name here), and the 3w6
    # sends its SUPER as RIGHTMETA
    [hotkey]
    enabled = true
    key = "EVTEST_19"
    modifiers = ["RIGHTMETA"]

    [audio]
    # ALSA's default is PipeWire, so this follows the default source in wpctl
    device = "default"
    sample_rate = 16000
    # room for a long hands-free take (SUPER+W)
    max_duration_secs = 300

    [parakeet]
    model = "parakeet-tdt-0.6b-v3"

    # typed at the cursor with wtype, held back until SUPER is released so the text
    # can't fire keybindings (wait_for_modifier_release, on by default)
    [output]
    mode = "type"

    # the text itself shows where it lands; mako only hears about takes with no speech
    [output.notification]
    on_transcription = false
    on_no_speech = true

    # the nixpkgs build has no gtk4 frontend
    [osd]
    frontend = "quickshell"
    style = "${osdStyle}"
    palette = "package"
  '';

  # the card's launcher finds quickshell on PATH
  programs.quickshell.enable = true;

  # supervised by systemd: it has to be up before the first SUPER+R.
  # The evdev hotkey needs the input group (configuration.nix)
  systemd.user.services.voxtype = {
    Unit = {
      Description = "Voxtype dictation daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      # the daemon reads config.toml only at start, and a switch restarts only changed units
      X-Restart-Triggers = [ config.xdg.configFile."voxtype/config.toml".source ];
    };
    Service = {
      ExecStart = "${voxtype}/bin/voxtype daemon";
      # the daemon spawns the card's launcher, which looks here before /usr/share
      Environment = "VOXTYPE_OSD_QML_PATH=${osdQml}";
      Restart = "always";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
