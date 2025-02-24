{ appearance, ... }:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
in
{
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        theme = {
          activeBorderColor = [
            (h n.nord8)
            "bold"
          ];
          inactiveBorderColor = [ (h n.nord3) ];
          searchingActiveBorderColor = [
            (h n.nord13)
            "bold"
          ];
          optionsTextColor = [ (h n.nord9) ];
          selectedLineBgColor = [ (h n.nord1) ];
          selectedRangeBgColor = [ (h n.nord1) ];
          cherryPickedCommitFgColor = [ (h n.nord14) ];
          cherryPickedCommitBgColor = [ (h n.nord10) ];
          unstagedChangesColor = [ (h n.nord11) ];
          defaultFgColor = [ (h n.nord4) ];
        };
      };
    };
  };
}
