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

        enableFishIntegration = mkEnableOption "Fish integration";

        enableBashIntegration = mkEnableOption "Bash integration";
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
        programs.fish.interactiveShellInit = mkIf cfg.enableFishIntegration ''
          set -gx PATH ${cfg.goBin} $PATH
        '';
        programs.bash.initExtra = mkIf cfg.enableBashIntegration ''
          export PATH=${cfg.goBin}:$PATH
        '';
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

  programs.go = rec {
    enable = true;
    goPath = "Codelearning/go";
    goMODCACHE = "Codelearning/go/pkg/mod";
    go111MODULE = "on";
    goBin = "${goPath}/bin";
    withMyGo = true;
    enableFishIntegration = if goBin != null then true else false;
    enableBashIntegration = if goBin != null then true else false;
    extraPackages = with pkgs; [
      graphviz
      pprof
      protobuf
      protoc-gen-go
      protoc-gen-go-grpc
      grpcurl
    ];
  };
}
