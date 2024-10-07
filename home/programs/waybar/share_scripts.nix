{ pkgs, ... }:
let
  wallpapers = {
    nord = {
      url = "https://raw.githubusercontent.com/Ruixi-rebirth/wallpaper/main/22.png";
      sha256 = "sha256-ZkuTlFDRPALR//8sbRAqiiAGApyqpKMA2zElRa2ABhY=";
    };
  };
  default_wall = wallpapers.nord or (throw "Unknown theme");
  wallpaper = pkgs.fetchurl {
    inherit (default_wall) url sha256;
  };
in
{
  cava-internal = pkgs.writeShellScriptBin "cava-internal" ''
    cava -p ~/.config/cava/config_internal | sed -u 's/;//g;s/0/▁/g;s/1/▂/g;s/2/▃/g;s/3/▄/g;s/4/▅/g;s/5/▆/g;s/6/▇/g;s/7/█/g;'
  '';
  wallpaper_random = pkgs.writeShellScriptBin "wallpaper_random" ''
    killall dynamic_wallpaper
    ${pkgs.swww}/bin/swww img $(find ~/Pictures/wallpaper/. -name "*.png" | shuf -n1) --transition-type random
  '';
  dynamic_wallpaper = pkgs.writeShellScriptBin "dynamic_wallpaper" ''
    ${pkgs.swww}/bin/swww img $(find ~/Pictures/wallpaper/. -name "*.png" | shuf -n1) --transition-type random
    OLD_PID=$!
    while true; do
        sleep 120
    ${pkgs.swww}/bin/swww img $(find ~/Pictures/wallpaper/. -name "*.png" | shuf -n1) --transition-type random
        NEXT_PID=$!
        sleep 5
        kill $OLD_PID
        OLD_PID=$NEXT_PID
    done
  '';
  default_wall = pkgs.writeShellScriptBin "default_wall" ''
    killall dynamic_wallpaper
    ${pkgs.swww}/bin/swww img "${wallpaper}" --transition-type random
  '';
}
