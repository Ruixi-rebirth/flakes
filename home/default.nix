{
  inputs,
  self,
  config,
  me,
  ...
}:
{
  imports = [
    inputs.nix-index-database.hmModules.nix-index
    inputs.nur.modules.homeManager.default
  ];

  home = {
    username = "${me.userName}";
    homeDirectory = "/home/${me.userName}";
    language.base = "en_US.UTF-8";
  };
  programs = {
    home-manager.enable = true;
  };

  home.stateVersion = "23.11";
}
