{ pkgs, ... }:
let
  wallpaper = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Ruixi-rebirth/someSource/main/wall/nord.png";
    sha256 = "sha256-ZkuTlFDRPALR//8sbRAqiiAGApyqpKMA2zElRa2ABhY=";
  };
in
{
  cava-internal = pkgs.writeShellScriptBin "cava-internal" ''
    killall cava
    cava -p ~/.config/cava/config_internal | sed -u 's/;//g;s/0/▁/g;s/1/▂/g;s/2/▃/g;s/3/▄/g;s/4/▅/g;s/5/▆/g;s/6/▇/g;s/7/█/g;'
  '';
  wallpaper_random = pkgs.writeShellScriptBin "wallpaper_random" ''
    killall dynamic_wallpaper
    ${pkgs.awww}/bin/awww img $(find ~/Pictures/wallpaper/. -name "*.png" | shuf -n1) --transition-type random
  '';
  dynamic_wallpaper = pkgs.writeShellScriptBin "dynamic_wallpaper" ''
    while true; do
      ${pkgs.awww}/bin/awww img $(find ~/Pictures/wallpaper/. -name "*.png" | shuf -n1) --transition-type random
      sleep 120
    done
  '';
  default_wall = pkgs.writeShellScriptBin "default_wall" ''
    killall dynamic_wallpaper
    ${pkgs.awww}/bin/awww img "${wallpaper}" --transition-type random
  '';
  recgif = pkgs.writeShellScriptBin "recgif" ''
    TIMESTAMP=$(date "+%Y-%m-%dT%H_%M_%S")
    TEMP_VIDEO="/tmp/recording_$TIMESTAMP.mkv"
    OUTPUT_GIF="$HOME/Pictures/recording_$TIMESTAMP.gif"
    GEOMETRY=$(slurp)
    if [[ $? -ne 0 ]]; then
      exit 1
    fi
    wf-recorder -f "$TEMP_VIDEO" -g "$GEOMETRY"
    if [[ -f "$TEMP_VIDEO" ]]; then
      ffmpeg -i "$TEMP_VIDEO" -vf "fps=15,scale=640:-1:flags=lanczos" -f gif "$OUTPUT_GIF"
      if [[ -f "$OUTPUT_GIF" ]]; then
        notify-send "GIF Conversion Complete" "GIF saved to $OUTPUT_GIF"
      fi
      rm "$TEMP_VIDEO"
    else
      notify-send "Recording Failed" "Video file not found"
    fi
  '';
}
