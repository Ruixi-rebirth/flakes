{ appearance, ... }:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
in
{
  services.mako = {
    enable = true;
    settings = {
      font = "${appearance.font.name} ${toString appearance.font.size}";
      width = 256;
      height = 500;
      margin = "10";
      padding = "5";
      borderSize = 3;
      borderRadius = 3;
      backgroundColor = h n.nord1;
      borderColor = h n.nord8;
      progressColor = "over ${h n.nord2}";
      textColor = h n.nord6;
      defaultTimeout = 5000;
      text-alignment = "center";
      "urgency=high" = {
        border-color = h n.nord11;
      };
    };
  };
}
