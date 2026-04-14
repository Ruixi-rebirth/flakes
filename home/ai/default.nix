{ pkgs, ... }:
let
  mcps = with pkgs; [
    flake-stats-mcp
  ];
in
{

  home.packages =
    with pkgs;
    [
      github-copilot-cli
      claude-code
      codex
      gemini-cli
    ]
    ++ mcps;
}
