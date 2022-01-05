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

      channelsConfig = { allowUnfree = true; };

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
            meta = with pkgs.lib; {
              description = "My awesome webpage";
              license = licenses.cc-by-nc-sa-40;
              platforms = platforms.all;
            };
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

          apps.serve = {
            type = "app";
            program = "${
              pkgs.writeShellScriptBin "my-hugo-serve" ''
                mkdir -p themes
                ln -s ${inputs.bookworm} themes/bookworm
                ${pkgs.hugo}/bin/hugo server
              ''
            }/bin/my-hugo-serve";
          };

        });


    };
}
