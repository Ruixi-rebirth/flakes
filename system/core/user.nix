{
  pkgs,
  me,
  ...
}:
{
  users.mutableUsers = false;
  users.users.root = {
    initialHashedPassword = me.initialHashedPassword;
    openssh.authorizedKeys.keys = [ me.sshPublicKey ];
  };
  users.users.${me.userName} = {
    initialHashedPassword = me.initialHashedPassword;
    shell = pkgs.fish;
    uid = 1000;
    isNormalUser = true;
    openssh.authorizedKeys.keys = [ me.sshPublicKey ];
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "kvm"
      "libvirtd"
      "adbusers"
    ];
  };
}
