{
  inputs,
  me,
  ...
}:
{
  imports = [
    inputs.nix-index-database.homeModules.nix-index
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

  home.enableNixpkgsReleaseCheck = false;
  home.stateVersion = "25.05";
}
