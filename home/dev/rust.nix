{ config, lib, pkgs, ... }:
let
  # Rust Module definition
  myRustModule = { config, lib, ... }:
    with lib;
    let
      cfg = config.programs.rust;
    in
    {
      options.programs.rust = {
        enable = mkEnableOption "Rust";

        package = mkOption {
          type = types.package;
          default = pkgs.rust-bin.stable.latest.default;
          description = "The Rust package to use.";
        };
      };

      config = mkIf cfg.enable {
        home.packages = [ cfg.package ];
      };
    };
in
{
  imports = [ myRustModule ];

  programs.rust = {
    enable = true;
  };
}
