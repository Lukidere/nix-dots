{
  description = "dhm's NixOS dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # dhmshell – personal fork of the Caelestia desktop shell
    # Build & install: sudo nixos-rebuild switch --flake .#legion
    # The Home Manager module (programs.caelestia) is wired up in home.nix.
    dhmshell = {
      url = "github:Lukidere/dhmshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    dhmshell,
    ...
  }: {
    nixosConfigurations.legion = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        # Provide home-manager as a NixOS module (replaces the old channel-based
        # <home-manager/nixos> import that was inside configuration.nix).
        home-manager.nixosModules.home-manager
        ./home.nix
        {
          # Make the dhmshell Home Manager module available to all HM users so
          # that `programs.caelestia` can be used in home.nix.
          home-manager.sharedModules = [
            dhmshell.homeManagerModules.default
          ];
        }
      ];
    };
  };
}
