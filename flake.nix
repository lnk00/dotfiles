{
  description = "lnk0's NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.home-manager.url = "github:nix-community/home-manager";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
  inputs.zen-browser.url = "github:0xc000022070/zen-browser-flake";
  inputs.zen-browser.inputs.nixpkgs.follows = "nixpkgs";
  inputs.zen-browser.inputs.home-manager.follows = "home-manager";
  inputs.hunk.url = "github:modem-dev/hunk";
  inputs.hunk.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, home-manager, zen-browser, hunk, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit zen-browser hunk; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
      ];
    };
  };
}
