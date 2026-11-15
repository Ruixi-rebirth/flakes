{ config, ... }:
{
  programs.go-musicfox = {
    enable = true;
    settings = {
      startup = {
        enable = false;
      };
      main = {
        downloadDir = "${config.home.homeDirectory}/Music";
      };
      theme = {
        activeTheme = "Nord";
      };
    };
  };
}
