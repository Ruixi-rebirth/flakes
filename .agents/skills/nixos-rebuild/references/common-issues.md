# NixOS Rebuild: Common Issues and Fixes

## 1. Dirty Flake Changes

If changes in the flake aren't being picked up:

- **Solution**: Ensure files are staged or committed in git. `nixos-rebuild` (and `nix flake`) only "sees" files that are tracked by git in a flake directory.
- **Command**: `git add <specific-dirty-files>`

## 2. Boot Partition Full

If the rebuild fails during bootloader configuration (e.g., systemd-boot):

- **Solution**: Remove old generations to free up space in `/boot`.
- **Command**: `sudo nix-collect-garbage -d` followed by `sudo nixos-rebuild boot` or `switch`.

## 3. Evaluation Failures (Syntax Errors)

If the Nix evaluation fails:

- **Solution**: Check the error message for the line number and file. Use `nix flake check` to catch issues before rebuilding.
- **Command**: `nix flake check`

## 4. Conflicting Home Manager Files

If Home Manager fails to apply because of existing files:

- **Solution**: Delete or rename the conflicting files manually, or use `home-manager.backupFileExtension = "backup";` (already enabled in this flake).
- **Command**: `rm <conflicting-file>`

## 5. Network Failures During Build

If fetching sources fails:

- **Solution**: Check network connection or try using a substituter/cache.
- **Command**: `nixos-rebuild switch --flake .#<host> --option substituters "https://cache.nixos.org https://nix-community.cachix.org"`

## 6. SUDO Requirements

`nixos-rebuild` generally requires `sudo` (or `doas`) to apply changes to the system and bootloader.

- **Solution**: Prepend `sudo` to the command.
- **Note**: The workspace script `lib/scripts/rebuild.sh` handles this automatically by detecting `doas` or `sudo`.
