{
  config,
  lib,
  pkgs,
  ...
}:
let
  myTypescriptModule =
    with lib;
    let
      cfg = config.programs.typescript;
    in
    {
      options.programs.typescript = {
        enable = mkEnableOption "TypeScript";

        nodePackage = mkOption {
          type = types.package;
          default = pkgs.nodejs;
          description = "The Node.js package to use.";
        };

        tsPackage = mkOption {
          type = types.package;
          default = pkgs.typescript;
          description = "The TypeScript package to use.";
        };

        extraPackages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "Additional packages for TypeScript development.";
        };
      };

      config = mkIf cfg.enable {
        home.packages = [
          cfg.nodePackage
          cfg.tsPackage
        ] ++ cfg.extraPackages;
      };
    };

in
{
  imports = [ myTypescriptModule ];

  programs.typescript = {
    enable = true;
    extraPackages = with pkgs; [
      bun
    ];
  };
}
