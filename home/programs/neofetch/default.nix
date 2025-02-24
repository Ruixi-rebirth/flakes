{ pkgs, ... }:
let
  config = import ./config.nix { inherit pkgs; };
in
{
  home.packages = [ pkgs.neofetch ];
  home.file = {
    ".config/neofetch/config.conf".text = config.neofetch;
  };
}
