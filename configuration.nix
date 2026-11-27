{ lib, pkgs, zen-browser, hunk, ... }:

let
  # nixpkgs' AppImage sandbox lacks libgpg-error, so Qt's xcb plugin fails and Vial exits at launch
  vial = pkgs.vial.override {
    appimageTools = pkgs.appimageTools // {
      wrapType2 = args: pkgs.appimageTools.wrapType2 (args // { extraPkgs = p: [ p.libgpg-error ]; });
    };
  };
in
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # nouveau keeps the atomic KMS ioctl to itself by default, and Jay won't drive a GPU without
  # it: the monitor is on the 4060 Ti
  boot.kernelParams = [ "nouveau.atomic=1" ];

  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  services.tailscale = {
    enable = true;
    # UDP 41641, lets peers connect directly instead of via DERP relays
    openFirewall = true;
    # use the AWS/DO subnet routers; *.preview/staging.fullenrich.com
    # split DNS points at 10.10.x.x, unreachable without these routes
    extraSetFlags = [ "--accept-routes" ];
  };

  time.timeZone = "America/Montevideo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users.users.lnk0 = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
    hashedPasswordFile = "/var/lib/secrets/lnk0.hash";
  };

  services.greetd = {
    enable = true;
    settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'jay run'";
  };

  # Jay has no NixOS module. It exports XDG_CURRENT_DESKTOP=jay, which picks
  # jay-portals.conf; gtk covers the rest
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.jay pkgs.xdg-desktop-portal-gtk ];
    config.jay = {
      default = [ "gtk" ];
      # screen sharing through the wlroots portal, for its fuzzel source picker: Jay's own
      # backend has a built-in one that can't be swapped
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      # remote control, which wlr doesn't do
      "org.freedesktop.impl.portal.RemoteDesktop" = [ "jay" ];
    };
    # fuzzel lists every monitor and window; jay.nix grants the capture protocols
    wlr = {
      enable = true;
      settings.screencast = {
        chooser_type = "dmenu";
        chooser_cmd = "${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt 'share '";
      };
    };
  };
  # Jay runs Xwayland from PATH, for X11 apps like Vial
  programs.xwayland.enable = true;
  programs.dconf.enable = true;

  fonts.enableDefaultPackages = true;
  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    # exposes headset battery level over D-Bus (shown in bluetui)
    settings.General.Experimental = true;
  };

  # onboard MediaTek BT (0e8d:0616) keeps logging "ACL packet for unknown connection handle";
  # deauthorize it so the UGREEN dongle is the only controller
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", ATTR{idProduct}=="0616", ATTR{authorized}="0"
  '';

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-tty;
  };

  # its udev rule hands the Keebart 3w6's hidraw nodes (serial vial:f64c2b3c) to the seat user
  services.udev.packages = [ vial ];

  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";
  # Jay has no setting to hide an idle cursor; the patch hides it after 5 s without
  # pointer input (CURSOR_HIDE_DELAY_NS) and the next motion, click or scroll brings it back.
  # It touches Jay's seat code, so a Jay update may need it rebased
  nixpkgs.overlays = [
    (final: prev: {
      jay = prev.jay.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./jay-hide-cursor.patch ];
      });
    })
  ];
  environment.systemPackages = with pkgs; [
    jay
    wl-clipboard
    git
    curl
    claude-code
    vial
  ];
  environment.variables.EDITOR = "hx";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit zen-browser hunk; };
    backupFileExtension = "hm-bak";
    users.lnk0 = import ./home;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # configurationLimit only trims the boot menu; this is what frees the store
  nix.gc = {
    automatic = true;
    dates = [ "weekly" ];
    options = "--delete-older-than 14d";
  };
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  system.stateVersion = "26.05";
}
