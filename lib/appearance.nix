let
  hexDigit =
    let
      table = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
        "A" = 10;
        "B" = 11;
        "C" = 12;
        "D" = 13;
        "E" = 14;
        "F" = 15;
      };
    in
    c: table.${c} or (throw "invalid hex digit: ${c}");

  hexByteToInt =
    s: (hexDigit (builtins.substring 0 1 s)) * 16 + (hexDigit (builtins.substring 1 1 s));
in
{
  font = {
    name = "Maple Mono NF CN";
    size = 12;
  };

  palettes = {
    nord = {
      # Polar Night
      nord0 = "2e3440";
      nord1 = "3b4252";
      nord2 = "434c5e";
      nord3 = "4c566a";
      # Snow Storm
      nord4 = "d8dee9";
      nord5 = "e5e9f0";
      nord6 = "eceff4";
      # Frost
      nord7 = "8fbcbb";
      nord8 = "88c0d0";
      nord9 = "81a1c1";
      nord10 = "5e81ac";
      # Aurora
      nord11 = "bf616a";
      nord12 = "d08770";
      nord13 = "ebcb8b";
      nord14 = "a3be8c";
      nord15 = "b48ead";
    };
  };

  # hex string → "#rrggbb"  (starship, fish, kitty, etc.)
  toHex = hex: "#${hex}";

  # hex string + alpha → "rgba(r,g,b,a)"  (zathura, GTK)
  toRgba =
    hex: alpha:
    let
      r = hexByteToInt (builtins.substring 0 2 hex);
      g = hexByteToInt (builtins.substring 2 2 hex);
      b = hexByteToInt (builtins.substring 4 2 hex);
    in
    "rgba(${toString r},${toString g},${toString b},${alpha})";

  # hex string → "38;2;r;g;b"  (EZA_COLORS, any ANSI true-color consumer)
  toAnsi =
    hex:
    let
      r = hexByteToInt (builtins.substring 0 2 hex);
      g = hexByteToInt (builtins.substring 2 2 hex);
      b = hexByteToInt (builtins.substring 4 2 hex);
    in
    "38;2;${toString r};${toString g};${toString b}";

}
