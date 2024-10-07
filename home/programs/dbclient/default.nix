{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      dbeaver-bin
    ];
  };
}
