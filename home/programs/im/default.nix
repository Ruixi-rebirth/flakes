{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      tdesktop
      qq
      # nur.repos.linyinfeng.icalingua-plus-plus
      (vesktop.overrideAttrs (oldAttrs: {
        postFixup =
          oldAttrs.postFixup or ""
          + ''
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
