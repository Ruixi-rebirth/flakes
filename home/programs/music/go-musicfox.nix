{
  config,
  lib,
  pkgs,
  ...
}:
let
  musicfoxModule =
    with lib;
    let
      tomlFormat = pkgs.formats.toml { };

      cfg = config.programs.go-musicfox;
    in
    {
      options.programs.go-musicfox = {
        enable = mkEnableOption "Go-MusicFox terminal music player";

        package = mkOption {
          type = types.package;
          default = pkgs.go-musicfox;
          description = "The package to use for the Go-MusicFox application.";
        };

        settings = mkOption {
          type = tomlFormat.type;
          default = { };
          example = literalExpression ''
            {
              startup = {
                show = true;
                progressOutBounce = true;
                loadingSeconds = 2;
                welcome = "musicfox";
                signIn = false;
                checkUpdate = true;
              };
            }
          '';
          description = "Go-MusicFox TOML configuration";
        };
      };

      config = mkIf cfg.enable {
        home.packages = [ cfg.package ];

        xdg.configFile."go-musicfox/config.toml" = mkIf (cfg.settings != { }) {
          source = tomlFormat.generate "go-musicfox-config" cfg.settings;
        };
      };
    };

in
{
  imports = [ musicfoxModule ];
  programs.go-musicfox = {
    enable = true;
    settings = {
      startup = {
        enable = false;
      };
      main = {
        downloadDir = "${config.home.homeDirectory}/Music";
      };
      theme = {
        primaryColor = "#e5e9f0";
      };
    };
  };
}
