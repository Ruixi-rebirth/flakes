{ inputs
, sharedModules
, wslModules
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
            ../modules/game.nix
            {
              home-manager = {
                extraSpecialArgs = { inherit user; };
                users.${user}.imports = homeImports."${user}@k-on";
              };
            }
          ] ++ sharedModules;
      };
      minimal = nixosSystem {
        specialArgs = { inherit user; };
        modules =
          [
            ./minimal
            ../modules/impermanence.nix
            ../modules/systemdboot.nix
          ] ++ sharedModules;
      };
      yu = nixosSystem {
        specialArgs = { inherit user; };
        modules =
          [
            ./yu
            {
              home-manager = {
                extraSpecialArgs = { inherit user; };
                users.${user}.imports = homeImports."${user}@yu";
              };
            }
          ] ++ wslModules;
      };
    };
}
