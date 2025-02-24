{ appearance }:
(import ./mk-theme.nix { inherit appearance; }).mkRofiTheme {
  windowWidth = "24%";
  lines = 6;
  showIcons = true;
  extraConfiguration = ''
    icon-theme:          "Papirus";
    display-drun:        "";
    drun-display-format: "{name}";
  '';
}
