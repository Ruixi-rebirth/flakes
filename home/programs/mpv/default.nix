{ pkgs, ... }:
{
  programs = {
    mpv = {
      enable = true;
      config = {
        # vo="gpu-next";  
        gpu-api = "opengl";
        gpu-context = "wayland";
        # hwdec="auto";
        hwdec = "auto-safe";
        vo = "gpu";
        profile = "gpu-hq";
        script-opts = "ytdl_hook-ytdl_path=yt-dlp";
      };
    };
  };
}
