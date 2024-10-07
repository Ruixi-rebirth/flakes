{
  pkgs,
  config,
  lib,
  me,
  ...
}:
{
  users.mutableUsers = false;
  users.users.root = {
    initialHashedPassword = "$6$lxmdznvXPgvRA.uq$R7Up1Eo1lrhaAbAGizrj/0dsbcU9DGKKVKLsA3bCrGYWkw/NkaQT.s41xTSqFkBZDXbucV00T2nN652D36AyG0";
  };
  users.users.${me.userName} = {
    initialHashedPassword = "$6$lxmdznvXPgvRA.uq$R7Up1Eo1lrhaAbAGizrj/0dsbcU9DGKKVKLsA3bCrGYWkw/NkaQT.s41xTSqFkBZDXbucV00T2nN652D36AyG0";
    shell = lib.mkIf (config.networking.hostName != "minimal") pkgs.fish or pkgs.bash;
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "video"
      "audio"
    ];
  };
}
