{ user, ... }:
{
  home = {
    username = "${user}";
    homeDirectory = "/home/${user}";
    language.base = "en_US.UTF-8";
  };
  programs = {
    home-manager.enable = true;
  };

  home.stateVersion = "23.11";
}
