{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "bilibili_live_tui";
  version = "06c76edde4051081e57beb19f46fb7bce365b176";

  src = fetchFromGitHub {
    owner = "yaocccc";
    repo = pname;
    rev = "${version}";
    sha256 = "sha256-uafKRsCvF/i4TDzdMTm+iYOowavAdUUUtjuFrrR36IY=";
  };

  vendorHash = "sha256-B0MWQGtxKKc02dxIS6jWkK120/tdD/Ow3LSKklBmLnw=";

  subPackages = [ "." ];

  ldflags = [
    "-w"
    "-s"
  ];

  meta = with lib; {
    description = "终端下使用的bilibili弹幕获取和弹幕发送服务";
    homepage = "https://github.com/yaocccc/bilibili_live_tui";
    mainProgram = "bili";
    platforms = platforms.linux;
  };
}
