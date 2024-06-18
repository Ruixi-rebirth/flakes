-- vim.o.number = false
local nvim_lsp = require("lspconfig")
nvim_lsp.nixd.setup({
	cmd = { "nixd" },
	settings = {
		nixd = {
			nixpkgs = {
				expr = 'import (builtins.getFlake ("git+file://" + toString ./.)).inputs.nixpkgs { }',
			},
			formatting = {
				command = { "nixpkgs-fmt" },
			},
			options = {
				nixos = {
					expr = '(builtins.getFlake ("git+file://" + toString ./.)).nixosConfigurations.k-on.options',
				},
				home_manager = {
					expr = '(builtins.getFlake ("git+file://" + toString ./.)).homeConfigurations."ruixi@k-on".options',
				},
				flake_parts = {
					expr =
					'let flake = builtins.getFlake ("git+file://" + toString ./.); in flake.debug.options // flake.currentSystem.options',
				},
			},
		},
	},
})
