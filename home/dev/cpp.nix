{
  config,
  lib,
  pkgs,
  ...
}:
let
  myCppModule =
    with lib;
    let
      cfg = config.programs.cpp;
    in
    {
      options.programs.cpp = {
        enable = mkEnableOption "C++ development environment";

        extraPackages = mkOption {
          type = types.listOf types.package;
          default = [
            pkgs.cmake
            pkgs.gdb
          ];
          description = "Additional packages for C++ development.";
        };
      };

      config = mkIf cfg.enable {
        home.packages = [
        ] ++ cfg.extraPackages;
      };
    };
in
{
  imports = [ myCppModule ];

  programs.cpp = {
    enable = true;
    extraPackages = with pkgs; [
      gnumake
      meson
      ninja
      cmake
      gdb
      lldb
      clang-tools
      bear
    ];
  };
}
