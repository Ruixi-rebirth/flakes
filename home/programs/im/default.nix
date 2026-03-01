{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      telegram-desktop
      wechat
      qq
      (feishu.override {
        nss = nss_latest; # Fix issue where Feishu documents cannot be opened due to NSS version mismatch
      })
      wemeet
      # nur.repos.linyinfeng.icalingua-plus-plus
      (vesktop.overrideAttrs (oldAttrs: {
        postFixup = oldAttrs.postFixup or "" + ''
          makeWrapper ${pkgs.electron}/bin/electron $out/bin/vesktop \
            --add-flags "$out/opt/Vesktop/resources/app.asar" \
            --add-flags "--enable-features=UseOzonePlatform" \
            --add-flags "--ozone-platform=x11";
        '';
      }))
      (element-desktop.override {
        commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=x11";
      })
    ];
  };
}
