{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    github-copilot-cli
    claude-code
    codex
    gemini-cli
  ];
}
