{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "r";
    flavors = {
      kanagawa = pkgs.fetchFromGitHub {
        owner = "dangooddd";
        repo = "kanagawa.yazi";
        rev = "b32f205";
        sha256 = "sha256-hi3RXCle+KTHlhnQwKDJiHTOro0At9QJMwY2hwWU8Ic=";
      };
    };
  };

  home.file = {
    ".config/yazi/yazi.toml".source = ./yazi.toml;
    ".config/yazi/keymap.toml".source = ./keymap.toml;
    ".config/yazi/theme.toml".source = ./theme.toml;
  };

}
