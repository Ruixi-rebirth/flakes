{ appearance, ... }:
let
  n = appearance.palettes.nord;
  a = appearance.toAnsi;
  mkEzaColors =
    mapping:
    builtins.concatStringsSep ":" (
      builtins.attrValues (builtins.mapAttrs (key: hex: "${key}=${a hex}") mapping)
    );
in
{
  home.sessionVariables.EZA_COLORS = mkEzaColors {
    # file types
    di = n.nord9; # directory
    ex = n.nord8; # executable
    ln = n.nord8; # symlink
    or = n.nord11; # broken symlink

    # permissions
    ur = n.nord13;
    uw = n.nord11;
    ux = n.nord8;
    ue = n.nord8;
    gr = n.nord13;
    gw = n.nord11;
    gx = n.nord8;
    tr = n.nord13;
    tw = n.nord11;
    tx = n.nord8;

    # metadata
    sn = n.nord9; # size number
    sb = n.nord3; # size unit
    da = n.nord3; # date
    uu = n.nord9; # current user
    un = n.nord3; # other user
    gu = n.nord15; # current group
    gn = n.nord3; # other group
  };
}
