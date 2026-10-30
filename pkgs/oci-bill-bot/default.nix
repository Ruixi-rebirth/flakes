{
  lib,
  stdenv,
  python3,
  sops,
}:
let
  pythonEnv = python3.withPackages (ps: [
    ps.oci
    ps.requests
    ps.cryptography
    ps.websockets
  ]);
in
stdenv.mkDerivation {
  pname = "oci-bill-bot";
  version = "0.1.0";

  src = ./.;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 oci_bill_bot.py $out/bin/oci-bill-bot
    substituteInPlace $out/bin/oci-bill-bot \
      --replace-fail "#!/usr/bin/env python3" "#!${pythonEnv}/bin/python3" \
      --replace-fail '"sops"' '"${sops}/bin/sops"'
    runHook postInstall
  '';

  meta = with lib; {
    description = "基于 QQ 官方 WebSocket 的 OCI 每日账单与防扣费巡检机器人";
    homepage = "https://github.com/Ruixi-rebirth/flakes";
    license = licenses.mit;
    mainProgram = "oci-bill-bot";
    platforms = platforms.unix;
  };
}
