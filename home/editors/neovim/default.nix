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
      };

      config = mkIf cfg.enable (mkMerge [
        {
          home.packages = [ cfg.package ];
          programs.fish.shellAliases = mkIf cfg.enableFishIntegration { vi = "nvim"; vim = "nvim"; };
        }

        (mkIf cfg.defaultEditor {
          home.sessionVariables.EDITOR = "nvim";
        })
      ]);
    };
in
{
  imports = [ myNeovimModule ];

  programs.nvim = {
    enable = true;
    defaultEditor = true;
    enableFishIntegration = true;
  };
}
