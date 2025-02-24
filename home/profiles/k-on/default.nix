{ lib, config, ... }:
{
  imports =
    [
      ../../wall
      ../../shell
      ../../dev
      ../../editors/neovim
      ../../terminals
      ../../programs
    ]
    ++ [
      ../../wm/sway
    ];

  wayland.windowManager.sway = lib.mkIf config.wayland.windowManager.sway.enable {
    extraOptions = [ "--unsupported-gpu" ];
  };

  # Autostart QEMU/KVM in the first initialization of NixOS
  # realted link: https://nixos.wiki/wiki/Virt-manager
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };
}
