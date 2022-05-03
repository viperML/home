{
  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    bookworm-light = pkgs.fetchFromGitHub {
      owner = "gethugothemes";
      repo = "bookworm-light";
      rev = "47981c600c2c6adde3af0742c2ab352d1464f46b";
      sha256 = "sha256-p4G8vKY/wnWpSJV0JK89R8wyZn/C6ecyrJZGkDkiDX0=";
    };
    themes = pkgs.runCommandNoCC "themes" {} ''
      mkdir -p $out/themes
      ln -s ${bookworm-light} $out/bookworm-light
    '';
  in {
    packages.${system}.default = with pkgs;
      stdenv.mkDerivation {
        pname = "home";
        version = self.lastModifiedDate;
        src = self;
        buildInputs = [hugo];
        HUGO_THEMESDIR = themes;
        buildPhase = ''
          mkdir -p $out
          hugo --minify --destination $out
        '';
        dontInstall = true;
      };
  };
}
