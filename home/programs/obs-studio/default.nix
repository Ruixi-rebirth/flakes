{ pkgs, ... }:
let
  obsThemes = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "obs";
    rev = "d90002a5315db3a43c39dc52c2a91a99c9330e1f";
    sha256 = "sha256-rU4WTj+2E/+OblAeK0+nzJhisz2V2/KwHBiJVBRj+LQ=";
  };
in
{
  programs = {
    obs-studio = {
      enable = true;
    };
  };
  home.file = {
    ".config/obs-studio/themes".source = "${obsThemes}/themes";
  };
}
