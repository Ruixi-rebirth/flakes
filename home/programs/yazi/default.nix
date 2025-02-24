let
  settings = import ./yazi.nix;
  theme = import ./theme.nix;
  keymap = import ./keymap.nix;
in
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "r";
    flavors = { };
    settings = settings;
    theme = theme;
    keymap = keymap;
  };
}
