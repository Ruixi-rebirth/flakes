{ pkgs, me, ... }:
{
  virtualisation = {
    docker.enable = true;
  };

  users.groups.docker.members = [ "${me.userName}" ];

  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
