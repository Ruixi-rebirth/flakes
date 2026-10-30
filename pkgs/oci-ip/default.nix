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
  ]);
in
stdenv.mkDerivation {
  pname = "oci-ip";
  version = "0.1.0";

  src = ./.;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 oci_ip.py $out/bin/oci-ip
    substituteInPlace $out/bin/oci-ip \
      --replace-fail "#!/usr/bin/env python3" "#!${pythonEnv}/bin/python3" \
      --replace-fail '"sops"' '"${sops}/bin/sops"'
    runHook postInstall
  '';

  meta = with lib; {
    description = "OCI 预留公网 IP 自动刷取（优质 IP 筛选）与无损绑定 CLI 工具";
    homepage = "https://github.com/Ruixi-rebirth/flakes";
    license = licenses.mit;
    mainProgram = "oci-ip";
    platforms = platforms.unix;
  };
}
