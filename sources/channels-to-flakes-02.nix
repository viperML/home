{
  outputs = {
    self,
    nixpkgs,
    home-manager,
  }: {
    nixosConfigurations.HOSTNAME = nixpkgs.lib.nixosSystem {
      # ...
      modules = [
        {
          nix.registry.nixpkgs.flake = nixpkgs;
        }
      ];
    };
    homeConfigurations.USER = home-manager.lib.homeManagerConfiguration {
      # ...
      modules = [
        {
          nix.registry.nixpkgs.flake = nixpkgs;
        }
      ];
    };
  };
}
