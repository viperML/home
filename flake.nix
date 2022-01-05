{
  description = "My flake";

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-utils-plus.url = github:gytis-ivaskevicius/flake-utils-plus;
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    bookworm = {
      url = github:gethugothemes/bookworm-light;
      flake = false;
    };
  };

  outputs = inputs @ { self, nixpkgs, flake-utils-plus, ... }:
    flake-utils-plus.lib.mkFlake {
      inherit self inputs;


      outputsBuilder = (channels:
        let
          pkgs = channels.nixpkgs;
        in
        {

          home = pkgs.stdenv.mkDerivation {
            name = "viperML-home";
            src = ./.;
            buildPhase = ''
              mkdir -p themes
              ln -s ${inputs.bookworm} themes/bookworm
              ${pkgs.hugo}/bin/hugo --minify
            '';
            installPhase = ''
              cp -r public $out
            '';
          };

          devShell = pkgs.mkShell {
            name = "viperML-home";
            shellHook = ''
              mkdir -p themes
              ln -s ${inputs.bookworm} themes/bookworm
            '';
            buildInputs = with pkgs; [
              hugo
            ];
          };

        });

    };
}
