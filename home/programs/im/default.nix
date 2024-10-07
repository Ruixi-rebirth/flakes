{ pkgs, config, ... }:
{
  home = {
    packages = (with pkgs; [
      tdesktop
      qq
    ]) ++ (with config.nur.repos;[
    ]);
  };
}
