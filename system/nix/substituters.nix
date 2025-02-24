{
  nix.settings = {
    substituters = [
      "https://nix-community.cachix.org"
      "https://ruixi-rebirth.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "ruixi-rebirth.cachix.org-1:ypGqoIU9MfXwv/fE02ZGg8mutJqmcYHgLTR1DMoPGac="
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
}
