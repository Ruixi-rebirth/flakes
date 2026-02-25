{ pkgs, ... }:
let
  mcps = with pkgs; [
    flake-stats-mcp
  ];
in
{
  environment.systemPackages =
    with pkgs;
    [
      github-copilot-cli
      claude-code
      codex
      gemini-cli
    ]++mcps;
}
