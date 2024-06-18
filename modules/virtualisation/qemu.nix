#Qemu/KVM with virt-manager
{ pkgs, user, ... }:
{
  environment = {
    systemPackages = with pkgs; [
      virt-manager
    ];
  };
  virtualisation = {
    libvirtd = {
      enable = true;
      # onBoot = "ignore";
    };
    spiceUSBRedirection.enable = true;
  };
  services = {
    spice-autorandr.enable = true;
    spice-vdagentd.enable = true;
  };
  networking.firewall.trustedInterfaces = [ "virbr0" ];
  programs.dconf.enable = true;
  users.groups.libvirtd.members = [ "${user}" ];
}
