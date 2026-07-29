{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    agenix.url = "github:ryantm/agenix";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      agenix,
      home-manager,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        "legion" = nixpkgs.lib.nixosSystem {
          # platform comes from hardware-configuration.nix (nixpkgs.hostPlatform)
          specialArgs = { inherit inputs; };
          modules = [
            agenix.nixosModules.default
            ./configuration.nix
            ./hardware-configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.dhm = import ./home.nix;
              home-manager.backupFileExtension = "bak";
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };
      };

    };
}
