{ appearance }:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
in
(import ./mk-theme.nix { inherit appearance; }).mkRofiTheme {
  windowWidth = "42%";
  lines = 12;
  placeholder = "Search clipboard...";
  extraListview = ''
    fixed-height: false;
    scrollbar:    true;
    cycle:        true;
  '';
  extraWidgets = ''
    scrollbar {
      handle-width:     4px;
      handle-color:     @se;
      background-color: @al;
      border-radius:    4px;
      margin:           0px 0px 0px 6px;
    }

    element urgent          { text-color: ${h n.nord11}; }
    element active          { text-color: ${h n.nord8}; }
    element selected.urgent { text-color: ${h n.nord11}; }
    element selected.active { text-color: ${h n.nord8}; }
  '';
}
