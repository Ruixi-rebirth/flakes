{ inputs
, sharedModules
, homeImports
, user
, ...
}: {
  flake.nixosConfigurations =
    let
      inherit (inputs.nixpkgs.lib) nixosSystem;
    in
    {
      k-on = nixosSystem {
        specialArgs = { inherit user; };
        modules =
          [
            ./k-on
            ../modules/lanzaboote.nix
            ../modules/impermanence.nix
            ../modules/desktop.nix
            ../modules/fonts.nix
            ../modules/virtualisation
            { home-manager.users.${user}.imports = homeImports."${user}@k-on"; }
          ]
          ++ sharedModules;
      };
      minimal = nixosSystem {
        specialArgs = { inherit user; };
        modules =
          [
            ./minimal
            ../modules/impermanence.nix
            ../modules/systemdboot.nix
            ../modules/impermanence.nix

          ] ++ sharedModules;
      };
    };
}
