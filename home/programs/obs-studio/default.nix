{ pkgs, ... }:
let
  obsThemes = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "obs";
    rev = "9a78d89";
    sha256 = "sha256-8DjAjpYsC9lEHe6gt/B7YCyfqVPaA5Qg1hbIMyyx/ho=";
  };
in
{
  programs = {
    obs-studio.enable = true;
  };
  home.file = {
    ".config/obs-studio/themes".source = "${obsThemes}/themes";
  };
}
