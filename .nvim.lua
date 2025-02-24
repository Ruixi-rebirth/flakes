-- vim.o.number = false
local nvim_lsp = vim.lsp
nvim_lsp.enable("nixd")

local flake_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")

local nixos_options_expr = 'let flake = builtins.getFlake ("git+file://'
  .. flake_root
  .. '"); in flake.nixosConfigurations.k-on.options // flake.nixosConfigurations.yu.options'
local home_manager_options_expr = nixos_options_expr .. ".home-manager.users.type.getSubOptions [ ]"
local flake_parts_options_expr = 'let flake = builtins.getFlake ("git+file://'
  .. flake_root
  .. '"); in flake.debug.options // flake.currentSystem.options'

nvim_lsp.config("nixd", {
  cmd = { "nixd" },
  filetypes = { "nix" },
  settings = {
    nixd = {
      nixpkgs = {
        expr = 'import (builtins.getFlake ("git+file://' .. flake_root .. '")).inputs.nixpkgs { }',
      },
      formatting = {
        command = { "nixfmt" },
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
