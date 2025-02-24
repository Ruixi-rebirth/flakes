{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      bilibili
    ];
  };
}
