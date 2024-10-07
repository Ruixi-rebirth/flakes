{ pkgs, inputs, ... }:
let
  flameshot-git = pkgs.flameshot.overrideAttrs (old: {
    src = inputs.flameshot-git;
    cmakeFlags = [ "-DUSE_WAYLAND_GRIM=true" ];
  });

  watermark = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Ruixi-rebirth/someSource/main/watermark/watermark3.png";
    sha256 = "sha256-imMR7X1sTZJWVuAQLsOMD4G/X/n9TY8C0zFLD1sNNQc=";
  };
  flameshot_watermark = pkgs.writeShellScriptBin "flameshot_watermark" ''
    FILE=$(date "+%Y-%m-%d"T"%H:%M:%S").png

    flameshot gui -r > $HOME/Pictures/src.png
    # add shadow, round corner, border and watermark
    convert $HOME/Pictures/src.png \
    	\( +clone -alpha extract \
    	-draw 'fill black polygon 0,0 0,8 8,0 fill white circle 8,8 8,0' \
    	\( +clone -flip \) -compose Multiply -composite \
    	\( +clone -flop \) -compose Multiply -composite \
    	\) -alpha off -compose CopyOpacity -composite $HOME/Pictures/output.png

    convert $HOME/Pictures/output.png -bordercolor none -border 20 \( +clone -background black -shadow 80x8+15+15 \) \
    	+swap -background transparent -layers merge +repage $HOME/Pictures/$FILE

    composite -gravity Southeast "${watermark}" $HOME/Pictures/$FILE $HOME/Pictures/$FILE
    if [[ "$XDG_CURRENT_DESKTOP"=="Hyprland" ]] || [[ "$XDG_CURRENT_DESKTOP"=="sway" ]];then 
    # Send the Picture to clipboard
        wl-copy < $HOME/Pictures/$FILE
    else
    # Send the Picture to clipboard
        xclip -selection clipboard -t image/png -i $HOME/Pictures/$FILE
    fi

    # remove the other pictures
    rm $HOME/Pictures/src.png $HOME/Pictures/output.png
  '';
in
{
  home.packages = [
    flameshot-git
    flameshot_watermark
  ];
  home.file = {
    ".config/flameshot/flameshot.ini".text = ''
      [General]
      checkForUpdates=false
      contrastOpacity=188
      showDesktopNotification=false
      showStartupLaunchMessage=false
    '';
  };
}
