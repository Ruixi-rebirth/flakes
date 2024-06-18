{ pkgs, ... }:
{
  programs.gpg.enable = true;
  programs.gpg.package = pkgs.gnupg;
  services = {
    gpg-agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-curses;
    };
  };
}
