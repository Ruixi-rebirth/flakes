{ pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      kdenlive
    ];
  };
}
