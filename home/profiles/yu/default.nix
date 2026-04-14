{
  imports = [
    ../../programs/wsl
    ../../shell
    ../../dev
    (import ../../editors/neovim { withGUI = true; })
    ../../ai
  ];
}
