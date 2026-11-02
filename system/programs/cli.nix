{
  pkgs,
  inputs,
  ...
}:
{
  environment.systemPackages =
    (with pkgs; [
      nix-tree
      gcc
      clang
      gdb
      inputs.nvim-flake.packages.${pkgs.stdenv.hostPlatform.system}.nvim
      wget
      fastfetch
      eza
      p7zip
      atool
      unzip
      zip
    ])
    ++ (pkgs.lib.optional (pkgs.stdenv.hostPlatform.isx86_64) pkgs.rar)
    ++ (with pkgs; [
      ffmpeg
      xdg-utils
      pciutils
      killall
      socat
      sops
      lsof
      rustscan
      onefetch
      jq
      tldr
      gptfdisk
      just
      android-tools
      nixfmt
    ]);
}
