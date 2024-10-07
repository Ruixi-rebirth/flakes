{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  myGoModule =
    with lib;
    let
      cfg = config.programs.go;
    in
    {
      options.programs.go = {
        go111MODULE = mkOption {
          type = with types; nullOr str;
          default = null;
          example = "on";
          description = "Whether to enable go111MODULE";
        };

        goMODCACHE = mkOption {
          type = with types; nullOr str;
          default = null;
          example = "go/pkg/mod";
          description = "The Go mod cache path";
        };

        withMyGo = mkOption {
          type = types.bool;
          default = true;
        };

        extraPackages = mkOption {
          type = with types; listOf package;
          default = [ ];
          description = "Additional packages to install, such as dependencies for Go programs.";
        };
      };

      config = {
        home.sessionVariables = (
          mkMerge [
            (mkIf (cfg.go111MODULE != null) {
              GO111MODULE = cfg.go111MODULE;
            })

            (mkIf (cfg.goMODCACHE != null) {
              GOMODCACHE = "${config.home.homeDirectory}/${cfg.goMODCACHE}";
            })
          ]
        );

        home.packages = (
          (
            if cfg.withMyGo then
              [
                inputs.mygo.packages.${pkgs.system}.default
              ]
            else
              [ ]
          )
          ++ cfg.extraPackages
        );

      };
    };
in
{
  imports = [ myGoModule ];

  programs.go = {
    enable = true;
    goPath = "Codelearning/go";
    goMODCACHE = "Codelearning/go/pkg/mod";
    go111MODULE = "on";
    withMyGo = true;
    extraPackages = with pkgs; [
      graphviz
      pprof
    ];
  };
}
