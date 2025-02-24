{ pkgs, appearance, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        fcitx5-rime
        qt6Packages.fcitx5-chinese-addons
        fcitx5-table-extra
        fcitx5-pinyin-moegirl
        fcitx5-pinyin-zhwiki
      ];
      waylandFrontend = true;
    };
  };
  home.file = {
    ".config/fcitx5/conf/classicui.conf".text = import ./classicui.nix { inherit appearance; };
    ".config/fcitx5/profile".text = import ./profile.nix;
    ".local/share/fcitx5/themes/Nord/theme.conf".text = import ./theme.nix { inherit appearance; };
  };
}
