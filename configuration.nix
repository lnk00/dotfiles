{ lib, pkgs, mangowm, zen-browser, hunk, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

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
    settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd mango";
  };

  programs.mango.enable = true;
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

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-tty;
  };

  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";
  environment.systemPackages = with pkgs; [
    wl-clipboard
    git
    curl
    claude-code
  ];
  environment.variables.EDITOR = "hx";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit mangowm zen-browser hunk; };
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
