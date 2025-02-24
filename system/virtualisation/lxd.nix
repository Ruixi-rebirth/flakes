{ me, ... }:
{
  virtualisation.lxd.enable = true;
  users.users.${me.userName} = {
    extraGroups = [ "lxd" ];
  };
}
