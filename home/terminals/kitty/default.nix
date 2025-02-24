{ appearance, ... }:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
in
{
  programs.kitty = {
    enable = true;
    font.name = appearance.font.name;
    font.size = 15;
    settings = {
      italic_font = "auto";
      bold_italic_font = "auto";
      mouse_hide_wait = 2;
      cursor_shape = "block";
      url_style = "dotted";
      confirm_os_window_close = 0;
      background_opacity = "0.95";
      dynamic_background_opacity = true;
      allow_remote_control = true;
    };
    extraConfig = ''
      foreground           ${h n.nord4}
      background           ${h n.nord0}
      selection_foreground ${h n.nord6}
      selection_background ${h n.nord3}
      url_color            ${h n.nord8}
      cursor               ${h n.nord9}

      # black
      color0  ${h n.nord1}
      color8  ${h n.nord3}

      # red
      color1  ${h n.nord11}
      color9  ${h n.nord11}

      # green
      color2  ${h n.nord14}
      color10 ${h n.nord14}

      # yellow
      color3  ${h n.nord13}
      color11 ${h n.nord13}

      # blue
      color4  ${h n.nord9}
      color12 ${h n.nord9}

      # magenta
      color5  ${h n.nord15}
      color13 ${h n.nord15}

      # cyan
      color6  ${h n.nord8}
      color14 ${h n.nord7}

      # white
      color7  ${h n.nord5}
      color15 ${h n.nord6}
    '';
  };
}
