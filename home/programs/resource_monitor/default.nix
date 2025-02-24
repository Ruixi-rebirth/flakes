{ pkgs, ... }:
{
  programs = {
    btop = {
      enable = true;
      settings = {
        color_theme = "nord";
        proc_tree = true;
        rounded_corners = false;
      };
    };
  };
  home.file = {
    ".config/btop/themes/nord.theme".source = ./theme.nix;
  };
}
