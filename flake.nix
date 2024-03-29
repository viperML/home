{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
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
      ];

      perSystem = {
        pkgs,
        config,
        ...
      }: {
        packages = {
          bookworm-light =
            pkgs.runCommand "bookworm-light"
            (pkgs.callPackage ./misc/generated.nix {}).theme
            ''
              cp -ra $src $out
              chmod +w $out/assets/scss/style.scss
              printf "\n\n%s\n" "@import 'overrides';" >> $out/assets/scss/style.scss
            '';

          themes = pkgs.linkFarmFromDrvs "themes" [config.packages.bookworm-light];

          default = pkgs.stdenvNoCC.mkDerivation {
            name = "home";
            src = nix-filter.lib {
              root = ./.;
              include = [
                (nix-filter.lib.inDirectory "assets")
                (nix-filter.lib.inDirectory "content")
                (nix-filter.lib.inDirectory "sources")
                (nix-filter.lib.inDirectory "static")
                "config.toml"
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
