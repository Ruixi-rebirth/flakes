{
  pkgs,
  inputs,
  me,
  ...
}:
let
  emanotePackage = inputs.emanote.packages.${pkgs.system}.emanote;
in
{
  systemd.user.services.emanote = {
    Unit = {
      Description = "Emanote ~/Blog";
      After = [ "network.target" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Restart = "always";
      ExecStart = "${emanotePackage}/bin/emanote -L /home/${me.userName}/Blog run --port=7000";
    };
  };
}
