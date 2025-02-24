{ pkgs, appearance, ... }:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
in
{
  home = {
    packages = with pkgs; [
      fd
      ripgrep
    ];
  };
  programs = {
    fzf = {
      enable = true;
      colors = {
        "bg" = h n.nord0;
        "bg+" = h n.nord2;
        "fg" = h n.nord4;
        "fg+" = h n.nord6;
        "hl" = h n.nord8;
        "hl+" = h n.nord8;
        "info" = h n.nord9;
        "prompt" = h n.nord9;
        "pointer" = h n.nord8;
        "marker" = h n.nord13;
        "spinner" = h n.nord8;
        "header" = h n.nord9;
        "border" = h n.nord3;
      };
    };
    bat = {
      enable = true;
      config.theme = "Nord";
    };
  };

  imports = [
    ./s.nix
  ];
}
