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
    in
    {
      k-on = nixosSystem {
        specialArgs = specialArgs // {
          enableLanzaboote = true;
        };
        modules = [
          ./k-on
          "${mod}/core"
          "${mod}/core/sops.nix"
          "${mod}/core/boot.nix"
          "${mod}/core/network.nix"
          "${mod}/core/impermanence.nix"
          "${mod}/nix"
          "${mod}/network/dae"
          "${mod}/programs/fonts.nix"
          "${mod}/programs/game.nix"
          "${mod}/programs/desktop.nix"
          "${mod}/hardware"
          "${mod}/virtualisation"
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.sops-nix.nixosModules.sops
          inputs.impermanence.nixosModules.impermanence
          inputs.disko.nixosModules.disko
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = specialArgs;
              users.${me.userName}.imports = homeImports."${me.userName}@k-on" or [ ];
            };
          }
        ];
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
          "${mod}/hardware"
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.impermanence.nixosModules.impermanence
          inputs.disko.nixosModules.disko
        ];
      };
      yu = nixosSystem {
        specialArgs = specialArgs;
        modules = [
          ./yu
          "${mod}/core"
          "${mod}/core/sops.nix"
          "${mod}/nix"
          inputs.nixos-wsl.nixosModules.wsl
          inputs.sops-nix.nixosModules.sops
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = specialArgs;
              users.${me.userName}.imports = homeImports."${me.userName}@yu" or [ ];
            };
          }
        ];
      };
    };
}
