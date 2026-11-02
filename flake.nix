{
  description = "lnk0's NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.home-manager.url = "github:nix-community/home-manager";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
  inputs.mangowm.url = "github:mangowm/mango";
  inputs.mangowm.inputs.nixpkgs.follows = "nixpkgs";
  inputs.zen-browser.url = "github:0xc000022070/zen-browser-flake";
  inputs.zen-browser.inputs.nixpkgs.follows = "nixpkgs";
  inputs.zen-browser.inputs.home-manager.follows = "home-manager";

  outputs = { nixpkgs, home-manager, mangowm, zen-browser, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit mangowm zen-browser; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
      ];
    };
  };
}
