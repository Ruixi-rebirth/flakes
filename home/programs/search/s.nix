{
  config,
  lib,
  pkgs,
  ...
}:
let
  sModule =
    with lib;
    let
      uclFormat = {
        type =
          with types;
          let
            valueType =
              nullOr (oneOf [
                bool
                int
                str
                (listOf valueType)
                (attrsOf valueType)
              ])
              // {
                description = "UCL value";
                emptyValue = { };
              };
          in
          valueType;

        generate =
          name: value:
          let
            toUCL =
              attrs:
              let
                filtered = filterAttrs (k: v: v != null) attrs;

                renderValue =
                  value:
                  if isString value then
                    "\"${value}\""
                  else if isInt value then
                    toString value
                  else if isBool value then
                    boolToString value
                  else if isList value then
                    "[${concatStringsSep ", " (map renderValue value)}]"
                  else if isAttrs value then
                    let
                      pairs = mapAttrsToList (n: v: "${n}: ${renderValue v}") value;
                    in
                    "{\n${concatMapStringsSep "\n" (s: "  ${s}") pairs}\n}"
                  else
                    throw "Unsupported type";

              in
              concatStringsSep "\n" (mapAttrsToList (name: value: "${name}: ${renderValue value}") filtered);
          in
          toUCL value;
      };

      cfg = config.programs.s;
    in
    {
      options.programs.s = {
        enable = mkEnableOption "s search tool";

        package = mkOption {
          type = types.package;
          default = pkgs.s-search;
          description = "The s package to use";
        };

        settings = mkOption {
          type = uclFormat.type;
          default = { };
          example = literalExpression ''
            {
              provider = "google";
              customProviders = [
                {
                  name = "nixpkgs";
                  url = "https://search.nixos.org/packages?query=%s";
                  tags = [ "nix" "packages" ];
                }
              ];
            }
          '';
          description = "s search tool configuration in UCL format";
        };
      };

      config = mkIf cfg.enable {
        home.packages = [ cfg.package ];

        xdg.configFile."s/config" = mkIf (cfg.settings != { }) {
          text = uclFormat.generate "s-config" cfg.settings;
        };
      };
    };

in
{
  imports = [ sModule ];

  programs.s = {
    enable = true;
    settings = {
      provider = "google";
      customProviders = [
        {
          name = "nixpkgs";
          url = "https://search.nixos.org/packages?query=%s";
          tags = [
            "nix"
            "packages"
          ];
        }
        {
          name = "nix_options";
          url = "https://search.nixos.org/options?query=%s";
          tags = [
            "nix"
            "options"
          ];
        }
        {
          name = "mynixos";
          url = "https://mynixos.com/search?q=%s";
        }
      ];
    };
  };
}
