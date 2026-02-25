{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "flake-stats-mcp";
  version = "1.0.0";

  src = ./.;

  vendorHash = null;

  meta = with lib; {
    description = "一个简单的 NixOS Flake 概览统计 MCP Server，用于演示 AI 工具扩展。";
    homepage = "https://github.com/Ruixi-rebirth/flakes";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    mainProgram = "flake-stats-mcp";
  };
}
