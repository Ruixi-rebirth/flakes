{ pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      fd
      bat
      ripgrep
    ];
  };
  programs = {
    fzf.enable = true;
  };

  imports = [
    ./s.nix
  ];
}
