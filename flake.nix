{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";

  outputs = {
    self,
    nixpkgs,
  }: let
    genSystems = nixpkgs.lib.genAttrs [
      "x86_64-linux"
      "aarch64-linux"
    ];
    pkgsFor = nixpkgs.legacyPackages;
  in {
    packages = genSystems (system: rec {
      bookworm-light = pkgsFor.${system}.fetchFromGitHub {
        owner = "gethugothemes";
        repo = "bookworm-light";
        rev = "47981c600c2c6adde3af0742c2ab352d1464f46b";
        sha256 = "sha256-p4G8vKY/wnWpSJV0JK89R8wyZn/C6ecyrJZGkDkiDX0=";
      };
      themes = pkgsFor.${system}.linkFarm "themes" [
        {
          name = "bookworm-light";
          path = bookworm-light;
        }
      ];
      default = with pkgsFor.${system};
        stdenv.mkDerivation {
          pname = "home";
          version = self.lastModifiedDate;
          src = self;
          nativeBuildInputs = [hugo];
          HUGO_THEMESDIR = themes;
          buildPhase = ''
            mkdir -p $out
            hugo --minify --destination $out
          '';
          dontInstall = true;
        };
        serve = with pkgsFor.${system}; writeShellScriptBin "serve" ''
          ${ran}/bin/ran -r ${default}
        '';
    });
    devShells = genSystems (system: {
      default = pkgsFor.${system}.mkShell {
        name = "hugo-devshell";
        inputsFrom = [self.packages.${system}.default];
        packages = [pkgsFor.${system}.nomad];
        HUGO_THEMESDIR = self.packages.${system}.themes;
        NOMAD_ADDR = "http://sumati:4646";
      };
    });
  };
}
