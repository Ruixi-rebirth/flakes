{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      aichat
      chatgpt-cli
    ];
  };
}
