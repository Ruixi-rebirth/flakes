{ config, lib, pkgs, ... }:
let
  # Module definition
  myGoModule = { config, lib, ... }:
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
      };

      config = {
        home.sessionVariables = (mkMerge [
          (mkIf (cfg.go111MODULE != null) {
            GO111MODULE = cfg.go111MODULE;
          })

          (mkIf (cfg.goMODCACHE != null) {
            GOMODCACHE = "${config.home.homeDirectory}/${cfg.goMODCACHE}";
          })
        ]);
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
  };
}
