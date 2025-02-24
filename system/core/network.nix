{
  # services.resolved.enable = true;
  networking = {
    # nameservers = [
    #   "8.8.8.8"
    #   "8.8.4.4"
    # ];
    networkmanager = {
      enable = true;
      # dns = "systemd-resolved";
    };
    firewall.allowedTCPPorts = [
      22 # sshd
      6600 # mpd
    ];
    hosts = {
      "185.199.109.133" = [ "raw.githubusercontent.com" ];
      "185.199.111.133" = [ "raw.githubusercontent.com" ];
      "185.199.110.133" = [ "raw.githubusercontent.com" ];
      "185.199.108.133" = [ "raw.githubusercontent.com" ];
    };
  };
}
