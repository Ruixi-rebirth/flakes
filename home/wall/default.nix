{ pkgs, config, ... }:
let
  wallpapers = {
    nord = {
      url = "https://raw.githubusercontent.com/Ruixi-rebirth/someSource/main/wall/nord.png";
      sha256 = "sha256-ZkuTlFDRPALR//8sbRAqiiAGApyqpKMA2zElRa2ABhY=";
    };
  };
  default_wall = wallpapers.nord or (throw "Unknown theme");
  wallpaper = pkgs.fetchurl {
    inherit (default_wall) url sha256;
  };
in
{
  systemd.user.services = {
    swww = {
      Unit = {
        Description = "Efficient animated wallpaper daemon for wayland";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = ''
          ${pkgs.swww}/bin/swww-daemon
        '';
        ExecStop = "${pkgs.swww}/bin/swww kill";
        Restart = "on-failure";
      };
    };
    default_wall = {
      Unit = {
        Description = "default wallpaper";
        Requires = [ "swww.service" ];
        After = [ "swww.service" ];
        PartOf = [ "swww.service" ];
      };
      Install.WantedBy = [ "swww.service" ];
      Service = {
        ExecStart = ''${pkgs.swww}/bin/swww img "${wallpaper}" --transition-type random'';
        Restart = "on-failure";
        Type = "oneshot";
      };
    };
  };
}
