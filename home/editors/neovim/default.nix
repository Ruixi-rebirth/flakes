{ config, lib, pkgs, inputs, ... }:
let
  # Neovim Module definition
  myNeovimModule = { config, lib, ... }:
    with lib;
    let
      cfg = config.programs.nvim;
    in
    {
      options.programs.nvim = {
        enable = mkEnableOption "Neovim";

        enableFishIntegration = mkEnableOption "Fish integration";

        package = mkOption {
          type = types.package;
          default = inputs.nvim-flake.packages.${pkgs.system}.nvim;
          example = "inputs.nvim-flake.packages.${pkgs.system}.lazynvim";
          description = "The Neovim package to use.";
        };

        defaultEditor = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to configure {command}`nvim` as the default
            editor using the {env}`EDITOR` environment variable.
          '';
        };

        withNixLSP = mkOption {
          type = types.bool;
          default = true;
        };
      };

      config = mkIf cfg.enable (mkMerge [
        {
          home.packages = [ cfg.package ];
          programs.fish.shellAliases = mkIf cfg.enableFishIntegration { vi = "nvim"; vim = "nvim"; };
        }

        (mkIf cfg.defaultEditor {
          home.sessionVariables.EDITOR = "nvim";
        })

        (mkIf cfg.withNixLSP {
          home.packages = with pkgs;[
            inputs.nixd.packages.${pkgs.system}.nixd
          ];
        })
      ]);
    };
in
{
  imports = [ myNeovimModule ];

  programs.nvim = {
    enable = true;
    package = inputs.nvim-flake.packages.${pkgs.system}.lazynvim;
    defaultEditor = true;
    enableFishIntegration = true;
    withNixLSP = true;
  };
}
