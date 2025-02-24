{
  config,
  lib,
  pkgs,
  ...
}:
let
  myRustModule =
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
          description = "The Rust toolchain package.";
        };

        withRustAnalyzer = mkOption {
          type = types.bool;
          default = true;
          description = "Install rust-analyzer LSP server.";
        };

        withRustSrc = mkOption {
          type = types.bool;
          default = false;
          description = "Install rust-src for macro expansion and go-to-definition in std.";
        };
      };

      config = mkIf cfg.enable {
        home.packages = [
          (if cfg.withRustSrc then cfg.package.override { extensions = [ "rust-src" ]; } else cfg.package)
        ]
        ++ optional cfg.withRustAnalyzer pkgs.rust-analyzer;
      };
    };
in
{
  imports = [ myRustModule ];

  programs.rust = {
    enable = true;
  };
}
