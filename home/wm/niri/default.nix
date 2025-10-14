{ pkgs, inputs, ... }:
{
  imports = [
    inputs.niri.homeModules.niri
  ]
  ++ [
    ./config.nix
  ];

  programs.niri = {
    enable = true;
    package = pkgs.niri-stable;
  };
}
