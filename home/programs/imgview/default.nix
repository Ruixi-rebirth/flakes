{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      imv
      swayimg
    ];
  };
}
