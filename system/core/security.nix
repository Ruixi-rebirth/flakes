{ me, ... }:
{
  security = {
    polkit.enable = true;
    rtkit.enable = true;
    sudo = {
      enable = true;
      extraConfig = ''
        Defaults env_keep += "http_proxy https_proxy ftp_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY"
        ${me.userName} ALL=(ALL) NOPASSWD:ALL
      '';
    };
    doas = {
      enable = true;
      extraConfig = ''
        permit nopass setenv { http_proxy https_proxy ftp_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY } :wheel
      '';
    };
  };

}
