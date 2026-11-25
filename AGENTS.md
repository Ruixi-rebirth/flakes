# Flakes Update & Deployment Rules

## Safe System Update Workflow (`oci`)

When updating flake inputs or system configurations (especially when executed from inside `daidai.service` / `agy` tickets):

1. **Update lockfile**:
   Run `nix flake update` (or `nix flake update <input>`) in `/home/ruixi/flakes`.
2. **Build-gate before switching**:
   Always run `nixos-rebuild build --flake .#oci` first. This validates the full closure (including any source-built `nixos-unstable-small` packages) without touching the running `daidai.service`. If the build fails, report the error and stop without switching.
3. **Commit lockfile changes** (when updating repository state):
   Commit `flake.lock` (and any config edits) cleanly before or after verification.
4. **Detached `switch`**:
   Never run `sudo nixos-rebuild switch` directly inside `daidai.service`'s cgroup—stopping `daidai.service` during `switch-to-configuration` will terminate sibling processes in the same unit. Instead, launch the switch in a detached transient systemd unit:
   ```bash
   sudo systemd-run \
     --unit="nixos-switch-$(date +%s)" \
     --property=WorkingDirectory=/home/ruixi/flakes \
     --setenv=PATH=/run/current-system/sw/bin:/run/wrappers/bin \
     /run/current-system/sw/bin/nixos-rebuild switch --flake .#oci
   ```

## Secrets

- Never inspect, decrypt, or print the contents of `secrets/secrets.yaml` unless explicitly requested in a `nix develop .#secret` workflow.
