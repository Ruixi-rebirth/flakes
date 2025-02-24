-- vim.o.number = false
local nvim_lsp = vim.lsp
nvim_lsp.enable("nixd")
local nixos_options_expr =
  'let flake = builtins.getFlake ("git+file://" + toString ./.); in flake.nixosConfigurations.k-on.options // flake.nixosConfigurations.yu.options'
local home_manager_options_expr = nixos_options_expr .. ".home-manager.users.type.getSubOptions [ ]"
local flake_parts_options_expr =
  'let flake = builtins.getFlake ("git+file://" + toString ./.); in flake.debug.options // flake.currentSystem.options'
nvim_lsp.config("nixd", {
  cmd = { "nixd" },
  settings = {
    nixd = {
      nixpkgs = {
        expr = 'import (builtins.getFlake ("git+file://" + toString ./.)).inputs.nixpkgs { }',
      },
      formatting = {
        command = { "nix fmt" },
      },
      options = {
        nixos = {
          expr = nixos_options_expr,
        },
        home_manager = {
          expr = home_manager_options_expr,
        },
        flake_parts = {
          expr = flake_parts_options_expr,
        },
      },
    },
  },
})
