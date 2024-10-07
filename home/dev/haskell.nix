{ config, lib, pkgs, ... }:

let
  # Haskell Module definition
  myHaskellModule = { config, lib, ... }:
    with lib;
    let
      cfg = config.programs.haskell;
    in
    {
      options.programs.haskell = {
        enable = mkEnableOption "Haskell";

        package = mkOption {
          type = types.package;
          default = pkgs.haskellPackages.ghc;
          description = "The Haskell package to use.";
        };

        enableCabal = mkOption {
          type = types.bool;
          default = false;
          description = "Enable the Cabal build tool.";
        };
      };

      config = mkIf cfg.enable (mkMerge [
        {
          home.packages = [ cfg.package ];
        }
        (mkIf cfg.enableCabal {
          home.packages = [ pkgs.haskellPackages.cabal-install ];
        })
      ]);
    };

in
{
  imports = [ myHaskellModule ];

  programs.haskell = {
    enable = true;
    enableCabal = true;
  };
}
