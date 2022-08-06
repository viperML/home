{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-parts,
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
      ];
      perSystem = {
        pkgs,
        self',
        ...
      }: {
        packages = {
          bookworm-light = pkgs.fetchFromGitHub rec {
            repo = "bookworm-light";
            name = repo;
            owner = "gethugothemes";
            rev = "47981c600c2c6adde3af0742c2ab352d1464f46b";
            sha256 = "sha256-p4G8vKY/wnWpSJV0JK89R8wyZn/C6ecyrJZGkDkiDX0=";
          };
          themes = pkgs.linkFarmFromDrvs "themes" [self'.packages.bookworm-light];
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "home";
            version = self.lastModifiedDate;
            src = self;
            nativeBuildInputs = [
              pkgs.hugo
              pkgs.asciidoctor
            ];
            HUGO_THEMESDIR = self'.packages.themes;
            buildPhase = ''
              mkdir -p $out
              hugo --minify --destination $out
            '';
            dontInstall = true;
          };
          serve = pkgs.writeShellScriptBin "serve" ''
            ${pkgs.ran}/bin/ran -r ${self'.packages.default}
          '';
        };
        devShells.default = pkgs.mkShellNoCC {
          name = "home";
          inputsFrom = [
            self'.packages.default
          ];
          packages = [
            pkgs.nomad
          ];
          HUGO_THEMESDIR = self'.packages.themes;
          shellHook = ''
            export NOMAD_VAR_rev=$(nix flake metadata . --json | jq -r '.locked.rev')
            export NOMAD_VAR_narHash=$(nix flake metadata . --json | jq -r '.locked.narHash')
          '';
        };
      };
    };
}
