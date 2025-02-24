{
  imports = [
    ../../programs/git
    ../../programs/lazygit
    ../../programs/gpg
    ../../programs/nix-index
    ../../programs/resource_monitor
    ../../programs/search
    ../../programs/ssh
    ../../programs/yazi
    ../../programs/zoxide
    ../../programs/fastfetch
    ../../shell
    ../../dev
    (import ../../editors/neovim { withGUI = true; })
    ../../ai
  ];
}
