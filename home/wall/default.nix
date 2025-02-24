{ pkgs, ... }:
let
  wallpaper = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Ruixi-rebirth/someSource/main/wall/nord.png";
    sha256 = "sha256-ZkuTlFDRPALR//8sbRAqiiAGApyqpKMA2zElRa2ABhY=";
  };
in
{
  systemd.user.services = {
    awww = {
      Unit = {
        Description = "Efficient animated wallpaper daemon for wayland";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.awww}/bin/awww-daemon";
        ExecStop = "${pkgs.awww}/bin/awww kill";
        Restart = "always";
        RestartSec = 3;
      };
    };

    default_wall = {
      Unit = {
        Description = "default wallpaper";
        BindsTo = [ "awww.service" ];
        After = [ "awww.service" ];
      };
      Install.WantedBy = [ "awww.service" ];
      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
        ExecStart = ''${pkgs.awww}/bin/awww img "${wallpaper}" --transition-type random'';
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    awww-resume-fix = {
      Unit = {
        Description = "Fix awww wallpaper after resume";
        After = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = pkgs.writeShellScript "awww-resume-fix" ''
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
