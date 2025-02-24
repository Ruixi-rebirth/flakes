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
      toGoMusicFoxIni = generators.toINI {
        mkKeyValue = key: value: "${key}=${toString value}";
      };

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
          type = types.attrs;
          default = { };
          example = {
            startup = {
              show = true;
              progressOutBounce = true;
              loadingSeconds = 2;
              welcome = musicfox;
              signIn = false;
              checkUpdate = true;
            };
          };
          description = ''
            Configuration options written to the Go-MusicFox INI file.
            More settings see: https://github.com/go-musicfox/go-musicfox/blob/master/utils/filex/embed/go-musicfox.ini
          '';
        };
      };
      config = mkIf cfg.enable {
        home.packages = [ cfg.package ];

        xdg.configFile."go-musicfox/go-musicfox.ini".text = ''
          ${toGoMusicFoxIni cfg.settings}
        '';
      };
    };

in
{
  imports = [ musicfoxModule ];
  programs.go-musicfox = {
    enable = true;
    settings = {
      main = {
        downloadDir = "${config.home.homeDirectory}/Music";
      };
    };
  };
}
