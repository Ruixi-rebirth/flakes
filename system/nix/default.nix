{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  imports = [
    ./nixpkgs.nix
    ./substituters.nix
  ];

  nix = {
    channel.enable = false;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      nix-path = lib.mkForce "nixpkgs=flake:nixpkgs";
      experimental-features = [
        "nix-command"
        "flakes"
        "auto-allocate-uids"
        "cgroups"
      ];
      auto-allocate-uids = true;
      use-cgroups = true;
      auto-optimise-store = true; # Optimise syslinks
      accept-flake-config = true;
      flake-registry = "${inputs.flake-registry}/flake-registry.json";
      builders-use-substitutes = true;
      keep-derivations = true;
      keep-outputs = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 2d";
    };
    package = pkgs.nixVersions.latest;
    registry.nixpkgs.flake = inputs.nixpkgs;
    extraOptions = ''
      keep-outputs            = true
      keep-derivations        = true
    '';
  };

}
