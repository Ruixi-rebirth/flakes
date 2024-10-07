{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraPkgs = pkgs: [ pkgs.wqy_zenhei ];
    };
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };
  environment.systemPackages = [
    pkgs.protontricks
  ];
}
