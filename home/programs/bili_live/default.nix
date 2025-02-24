{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      bili_tui
    ];
  };
}
