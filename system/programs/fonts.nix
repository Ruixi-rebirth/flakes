{ pkgs, ... }:
let
  maple-mono-NF-CN = pkgs.maple-mono.NF.overrideAttrs (_: rec {
    version = "7.0-beta36";
    pname = "MapleMono-NF-CN";
    src = pkgs.fetchurl {
      url = "https://github.com/subframe7536/Maple-font/releases/download/v${version}/${pname}.zip";
      sha256 = "sha256-W5b4jcr6fGaAbasCXCswGMkG/SklCXUbfRcPvZfzsNo=";
    };
  });

  nerdFonts = with pkgs.nerd-fonts; [
    # fonts name can get in `https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/data/fonts/nerdfonts/shas.nix`
    hack
    jetbrains-mono
    iosevka
    daddy-time-mono
    symbols-only
  ];
in
{
  fonts = {
    packages =
      with pkgs;
      [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
        maple-mono-NF-CN
      ]
      ++ nerdFonts;
    fontconfig = {
      enable = true;
      defaultFonts = {
        emoji = [ "Noto Color Emoji" ];
        serif = [
          "Maple Mono NF CN"
          "Noto Serif CJK SC"
          "Noto Serif"
        ];
        sansSerif = [
          "Maple Mono NF CN"
          "Noto Sans CJK SC"
          "Noto Sans"
        ];
        monospace = [
          "Maple Mono NF CN"
          "Noto Sans Mono CJK SC"
        ];
      };
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <!-- Default system-ui fonts -->
          <match target="pattern">
            <test name="family">
              <string>system-ui</string>
            </test>
            <edit name="family" mode="prepend" binding="strong">
              <string>sans-serif</string>
            </edit>
          </match>

          <match target="pattern">
            <test name="lang" compare="contains">
              <string>zh</string>
            </test>
            <edit name="family" mode="prepend" binding="strong">
              <string>Maple Mono NF CN</string>
            </edit>
          </match>

          <match target="pattern">
            <test name="lang" compare="contains">
              <string>en</string>
            </test>
            <edit name="family" mode="prepend" binding="strong">
              <string>Maple Mono NF CN</string>
            </edit>
          </match>

          <match target="pattern">
            <test name="lang">
              <string>zh-HK</string>
            </test>
            <test name="family">
              <string>Noto Sans CJK SC</string>
            </test>
            <edit name="family" binding="strong">
              <string>Noto Sans CJK HK</string>
            </edit>
          </match>

          <match target="pattern">
            <test name="lang">
              <string>zh-TW</string>
            </test>
            <test name="family">
              <string>Noto Sans CJK SC</string>
            </test>
            <edit name="family" binding="strong">
              <string>Noto Sans CJK TC</string>
            </edit>
          </match>

          <match target="pattern">
            <test name="lang">
              <string>ja</string>
            </test>
            <test name="family">
              <string>Noto Sans CJK SC</string>
            </test>
            <edit name="family" binding="strong">
              <string>Noto Sans CJK JP</string>
            </edit>
          </match>

          <match target="pattern">
            <test name="lang" compare="contains">
              <string>en</string>
            </test>
            <test name="family" compare="contains">
              <string>Noto Serif CJK</string>
            </test>
            <edit name="family" mode="prepend" binding="strong">
              <string>Noto Serif</string>
            </edit>
          </match>
        </fontconfig>
      '';
    };
  };
}
