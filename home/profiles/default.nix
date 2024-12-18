{
  inputs,
  withSystem,
  module_args,
  ...
}:
let
  user = "ruixi";
  domain = "ruixi2fp.top";

  sharedModules = [
    (import ../. { inherit user; })
    module_args
    inputs.nix-index-database.hmModules.nix-index
    inputs.nur.modules.homeManager.default
  ];

  homeImports = {
    "${user}@k-on" = [ ./k-on ] ++ sharedModules;
    "${user}@yu" = [ ./yu ] ++ sharedModules;
  };

  inherit (inputs.home-manager.lib) homeManagerConfiguration;
in
{
  imports = [
    # we need to pass this to NixOS' HM module
    {
      _module.args = {
        inherit homeImports user;
      };
    }
  ];

  flake = {
    homeConfigurations = withSystem "x86_64-linux" (
      { pkgs, ... }:
      {
        "${user}@k-on" = homeManagerConfiguration {
          modules = homeImports."${user}@k-on";
          inherit pkgs;
        };
        "${user}@yu" = homeManagerConfiguration {
          modules = homeImports."${user}@yu";
          inherit pkgs;
        };
      }
    );
  };
}
