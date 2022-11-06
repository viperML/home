{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = {
    self,
    nixpkgs,
    flake-parts,
    nix-filter,
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
      ];

      perSystem = {
        pkgs,
        config,
        ...
      }: {
        packages = {
          bookworm-light =
            pkgs.runCommand "bookworm-light" {
              src = pkgs.fetchFromGitHub {
                repo = "bookworm-light";
                owner = "gethugothemes";
                rev = "47981c600c2c6adde3af0742c2ab352d1464f46b";
                hash = "sha256-p4G8vKY/wnWpSJV0JK89R8wyZn/C6ecyrJZGkDkiDX0=";
              };
            } ''
              cp -ra $src $out
              chmod +w $out/assets/scss/style.scss
              printf "\n\n%s\n" "@import 'overrides';" >> $out/assets/scss/style.scss
            '';

          themes = pkgs.linkFarmFromDrvs "themes" [config.packages.bookworm-light];

          default = pkgs.stdenvNoCC.mkDerivation {
            name = "home";
            src = nix-filter.lib {
              root = ./.;
              exclude = [
                (nix-filter.lib.matchExt "nix")
                (nix-filter.lib.matchExt "yaml")
              ];
            };
            nativeBuildInputs = with pkgs; [
              hugo
              asciidoctor
            ];
            HUGO_THEMESDIR = config.packages.themes;
            buildPhase = ''
              runHook preBuild
              mkdir -p $out
              hugo --minify --destination $out
              runHook postBuild
            '';
            dontInstall = true;
          };

          serve = pkgs.writeShellScriptBin "serve" ''
            ${pkgs.ran}/bin/ran -r ${config.packages.default}
          '';
        };

        legacyPackages = pkgs;
      };
    };
}
