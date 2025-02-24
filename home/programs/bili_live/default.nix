{ inputs, pkgs, ... }:
{
  home.packages = [ inputs.bili-live-tui.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
