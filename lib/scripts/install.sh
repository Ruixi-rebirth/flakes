#!/usr/bin/env bash

set -e

# Change directory to the flake root (installer location).
# This script assumes the flake has been copied to /mnt/etc/nixos/flakes
# as performed by the 'disko.sh' script.
if [ ! -d "/mnt/etc/nixos/flakes" ]; then
  echo "❌ Error: Flake not found at /mnt/etc/nixos/flakes. Please run 'disko.sh' first or ensure the flake is mounted correctly." >&2
  exit 1
fi
cd /mnt/etc/nixos/flakes

function set_user_passwd {
  if ! command -v mkpasswd &>/dev/null; then
    echo "❌ Error: 'mkpasswd' command not found. Cannot set user password." >&2
    exit 1
  fi
  echo $'\e[1;32mSet your user login password:\e[0m'
  while true; do
    read -s -p "Enter password: " user_pass
    echo
    read -s -p "Confirm password: " user_pass_confirm
    echo

    if [ "$user_pass" != "$user_pass_confirm" ]; then
      echo "Passwords do not match. Please try again."
    else
      echo "Password confirmed."
      # mkpasswd is usually available in NixOS installer
      passwd_hash=$(echo "$user_pass" | mkpasswd -m sha-512 -s || {
        echo "❌ Error generating password hash." >&2
        exit 1
      })
      break
    fi
  done
}

# 1. Dynamically discover hosts from flake
echo "🕵️ Discovering hosts from flake..."
# Note: We use --extra-experimental-features to ensure nix commands work in installer
if ! hosts_json=$(nix --extra-experimental-features "nix-command flakes" flake show --json 2>/dev/null); then
  echo "❌ Error: 'nix flake show' failed in installer environment." >&2
  exit 1
fi
hosts=($(echo "$hosts_json" | jq -r '.nixosConfigurations | keys[]'))

if [ ${#hosts[@]} -eq 0 ]; then
  echo "❌ No NixOS configurations found in flake or 'jq' failed to parse." >&2
  exit 1
fi

while true; do
  echo "--------------------------------------------------------"
  echo "💡 Installation Suggestions:"
  echo "- minimal: Highly recommended for initial installation (stable & fast)."
  echo "- yu: Based on WSL (Windows Subsystem for Linux)."
  echo "- k-on: Regular NixOS full configuration."
  echo "⚠️  RAM Recommendation: > 8GB"
  echo "   (Small RAM may cause 'No space left on device' in Live environment)"
  echo "--------------------------------------------------------"
  echo "The partition is now complete, please select the device you wish to install:"
  for i in "${!hosts[@]}"; do
    echo "$((i + 1)). ${hosts[$i]}"
  done

  read -p $'\e[1;32mEnter your choice (number): \e[0m' -r choice

  # Validate choice
  if [[ ! $choice =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#hosts[@]}" ]; then
    echo "❌ Invalid choice, please try again."
    continue
  fi

  selected_host="${hosts[$((choice - 1))]}"

  # 2. Set password and update me.nix
  set_user_passwd
  # WARNING: Direct 'sed' modification of Nix files can be brittle.
  # Consider more robust Nix mechanisms like sops-nix for secrets,
  # or passing configurations dynamically if possible.
  echo "📝 Updating initialHashedPassword in me.nix..."
  sed -i "/initialHashedPassword/c\ \ \ \ initialHashedPassword\ =\ \"$passwd_hash\";" ./me.nix

  # 3. Execute installation
  echo "🚀 Starting nixos-install for $selected_host..."
  nixos-install --no-root-passwd --flake ".#$selected_host"
  break
done
