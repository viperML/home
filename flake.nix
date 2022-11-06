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

          themes = pkgs.linkFarmFromDrvs "themes" [self'.packages.bookworm-light];

          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "home";
            version = builtins.substring 0 8 self.lastModifiedDate;
            src = self;
            nativeBuildInputs = [
              pkgs.hugo
              pkgs.asciidoctor
            ];
            HUGO_THEMESDIR = self'.packages.themes;
            buildPhase = ''
              runHook preBuild
              mkdir -p $out
              hugo --minify --destination $out
              runHook postBuild
            '';
            dontInstall = true;
          };

          vercel = pkgs.runCommand "vercel-home" {} ''
            mkdir -p $out
            ln -s ${config.packages.default} $out/static

            tee $out/config.json <<EOF
            {
              "version": 3,
              "routes": [
                {
                  "handle": "error"
                },
                {
                  "status": 404,
                  "src": "^(?!/api).*$",
                  "dest": "/404.html"
                }
              ]
            }
            EOF
          '';

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
        };
      };
    };
}
