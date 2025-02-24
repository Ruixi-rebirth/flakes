{
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      nix-direnv.enable = true;
      config = { };
    };

    bash.enable = true;
    fish.enable = true;
  };
}
