{ pkgs, ... }:
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "nord";
      proc_tree = true;
      rounded_corners = false;
    };
  };
}
