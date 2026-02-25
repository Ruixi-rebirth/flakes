{ pkgs, ... }:
let
  wallpapers = {
    nord = {
      url = "https://raw.githubusercontent.com/Ruixi-rebirth/someSource/main/wall/nord.png";
      sha256 = "sha256-ZkuTlFDRPALR//8sbRAqiiAGApyqpKMA2zElRa2ABhY=";
    };
  };
  default_wall_item = wallpapers.nord or (throw "Unknown theme");
  wallpaper = pkgs.fetchurl {
    inherit (default_wall_item) url sha256;
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
        ExecStart = "${pkgs.swww}/bin/swww-daemon";
        ExecStop = "${pkgs.swww}/bin/swww kill";
        Restart = "always";
        RestartSec = 3;
      };
    };

    default_wall = {
      Unit = {
        Description = "default wallpaper";
        BindsTo = [ "swww.service" ];
        After = [ "swww.service" ];
      };
      Install.WantedBy = [ "swww.service" ];
      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
        ExecStart = ''${pkgs.swww}/bin/swww img "${wallpaper}" --transition-type random'';
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    swww-resume-fix = {
      Unit = {
        Description = "Fix swww wallpaper after resume";
        After = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = pkgs.writeShellScript "swww-resume-fix" ''
          ${pkgs.dbus}/bin/dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" | \
          while read -r line; do
              if [[ "$line" == *"boolean false"* ]]; then
                  echo "Detected system resume, waiting for GPU and Wayland to settle..."
                  ${pkgs.coreutils}/bin/sleep 0.5
                  ${pkgs.systemd}/bin/systemctl --user restart default_wall
              fi
          done
        '';
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
