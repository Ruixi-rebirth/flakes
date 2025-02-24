{
  inputs,
  me,
  ...
}:
{
  imports = [
    inputs.nix-index-database.hmModules.nix-index
  ];

  home = {
    username = "${me.userName}";
    homeDirectory = "/home/${me.userName}";
    language.base = "en_US.UTF-8";
    sessionVariables = {
      NIX_AUTO_RUN = "1";
    };
  };
  programs = {
    home-manager.enable = true;
  };

  home.stateVersion = "23.11";
}
