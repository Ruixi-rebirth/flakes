{ appearance }:
(import ./mk-theme.nix { inherit appearance; }).mkRofiTheme {
  windowWidth = "20%";
  lines = 5;
}
