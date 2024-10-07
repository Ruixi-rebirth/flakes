{ pkgs, config, ... }:
{
  home = {
    packages =
      (with pkgs; [
        tdesktop
        qq
        vesktop
        element-desktop
      ])
      ++ (with config.nur.repos; [
      ]);
  };
}
