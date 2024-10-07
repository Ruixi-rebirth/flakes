{ stdenv
, lib
, fetchurl
}:
stdenv.mkDerivation {
  pname = "fcitx5-pinyin-moegirl";
  version = "20240609";

  src = fetchurl {
    url = "https://github.com/outloudvi/mw2fcitx/releases/download/20240609/moegirl.dict";
    sha256 = "sha256-dXFV0kVr8hgT17Jmr28PiYTiELm8kS/KM71igHXA6hs=";
  };

  dontUnpack = true;
  installPhase = ''
    install -Dm644 $src $out/share/fcitx5/pinyin/dictionaries/moegirl.dict
  '';
  meta = with lib; {
    description = "Fcitx 5 PinyinDictionary from zh.moegirl.org.cn ";
    homepage = "https://github.com/outloudvi/mw2fcitx";
    license = licenses.unlicense;
  };
}
