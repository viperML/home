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
          environment.etc."nix/inputs/nixpkgs".source = nixpkgs.outPath;
          nix.nixPath = ["nixpkgs=/etc/nix/inputs/nixpkgs"];
        }
      ];
    };
    homeConfigurations.USER = home-manager.lib.homeManagerConfiguration {
      # ...
      modules = [
        {
          xdg.configFile."nix/inputs/nixpkgs".source = nixpkgs.outPath;
          home.sessionVariables.NIX_PATH = "nixpkgs=${config.xdg.configHome}/nix/inputs/nixpkgs$\{NIX_PATH:+:$NIX_PATH}";
        }
      ];
    };
  };
}
