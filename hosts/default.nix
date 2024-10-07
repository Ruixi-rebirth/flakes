{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations =
    let
      me = import ../me.nix;
    in
    let
      inherit (inputs.nixpkgs.lib) nixosSystem;
      homeImports = import "${self}/home/profiles";
      mod = "${self}/system";
      specialArgs = {
        inherit inputs self me;
      };
      sharedModules = [
        inputs.home-manager.nixosModule
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
          };
        }
        inputs.lanzaboote.nixosModules.lanzaboote
        inputs.impermanence.nixosModules.impermanence
        inputs.sops-nix.nixosModules.sops
        inputs.disko.nixosModules.disko
      ];
    in
    {
      k-on = nixosSystem {
        specialArgs = specialArgs // {
          enableLanzaboote = true;
        };
        modules = [
          ./k-on
          "${mod}/core"
          "${mod}/core/boot.nix"
          "${mod}/core/network.nix"
          "${mod}/core/impermanence.nix"
          "${mod}/core/boot.nix"
          "${mod}/nix"
          "${mod}/network/dae"
          "${mod}/programs/fonts.nix"
          "${mod}/programs/game.nix"
          "${mod}/programs/desktop.nix"
          "${mod}/hardware/bluetooth.nix"
          "${mod}/virtualisation"
          {
            home-manager = {
              extraSpecialArgs = specialArgs;
              users.${me.userName}.imports = homeImports."${me.userName}@k-on" or [ ];
            };
          }
        ] ++ sharedModules;
      };
      minimal = nixosSystem {
        specialArgs = specialArgs // {
          enableLanzaboote = false;
        };
        modules = [
          ./minimal
          "${mod}/core"
          "${mod}/core/boot.nix"
          "${mod}/core/network.nix"
          "${mod}/core/impermanence.nix"
          "${mod}/nix"
          "${mod}/network/dae"
          "${mod}/hardware/bluetooth.nix"
        ] ++ sharedModules;
      };
      yu = nixosSystem {
        specialArgs = specialArgs;
        modules =
          [
            ./yu
            "${mod}/core"
            "${mod}/nix"
            {
              home-manager = {
                extraSpecialArgs = specialArgs;
                users.${me.userName}.imports = homeImports."${me.userName}@yu";
              };
            }
          ]
          ++ [
            inputs.home-manager.nixosModule
            inputs.nixos-wsl.nixosModules.wsl
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
              };
            }
            inputs.sops-nix.nixosModules.sops
          ];
      };
    };
}
