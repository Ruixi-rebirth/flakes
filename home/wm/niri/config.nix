{ pkgs, ... }:
{
  programs.niri = {
    settings = {
      input = {
        mod-key = "Alt";
        mod-key-nested = "Super";
      };
      binds = {
        "Mod+Return" = {
          repeat = false;
          action.spawn = "kitty";
        };
      };
    };
  };
}
