{
  pkgs,
  appearance,
  ...
}:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
in
{
  imports = [
    ./go-musicfox.nix
  ];
  home = {
    packages = with pkgs; [
      mpc
      pear-desktop
    ];
  };
  programs = {
    ncmpcpp = {
      enable = true;
      mpdMusicDir = null;
      settings = {
        mpd_music_dir = "~/Music";
      };
    };
    cava = {
      enable = true;
      settings = {
        color = {
          gradient = 1;
          gradient_count = 5;
          gradient_color_1 = "'${h n.nord9}'";
          gradient_color_2 = "'${h n.nord7}'";
          gradient_color_3 = "'${h n.nord15}'";
          gradient_color_4 = "'${h n.nord6}'";
          gradient_color_5 = "'${h n.nord13}'";
        };
      };
    };
  };
  home.file.".config/cava/config_internal".text = ''
    [general]
    bars = 12
    sleep_timer = 10
    [output]
    method = raw
    data_format = ascii
    ascii_max_range = 7
  ''; # ../waybar/{share_scripts.nix}.config_internal
  services = {
    mpd = {
      enable = true;
      musicDirectory = "~/Music";
      network = {
        listenAddress = "0.0.0.0";
        port = 6600;
      };
      extraConfig = ''
        audio_output {
          type  "pipewire"
          name  "PipeWire Sound Server"
        }
      '';
    };
  };
}
