{ pkgs, config, ... }:
{
  home = {
    packages = (with pkgs; [
      tdesktop
    ]) ++ (with config.nur.repos;[
    ]);
  };
}
