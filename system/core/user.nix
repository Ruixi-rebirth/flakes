{
  pkgs,
  me,
  ...
}:
{
  users.mutableUsers = false;
  users.users.root = {
    initialHashedPassword = me.initialHashedPassword;
  };
  users.users.${me.userName} = {
    initialHashedPassword = me.initialHashedPassword;
    shell = pkgs.fish;
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "video"
      "audio"
    ];
  };
}
