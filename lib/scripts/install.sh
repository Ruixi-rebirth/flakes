#!/usr/bin/env bash

set -e

# Change directory to the flake root (installer location)
cd /mnt/etc/nixos/flakes

function set_user_passwd {
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
      passwd_hash=$(echo "$user_pass" | mkpasswd -m sha-512 -s 2>/dev/null)
      break
    fi
  done
}

# 1. Dynamically discover hosts from flake
echo "🕵️ Discovering hosts from flake..."
# Note: We use --extra-experimental-features to ensure nix commands work in installer
hosts=($(nix --extra-experimental-features "nix-command flakes" flake show --json 2>/dev/null | jq -r '.nixosConfigurations | keys[]'))

if [ ${#hosts[@]} -eq 0 ]; then
  echo "❌ No NixOS configurations found in flake."
  exit 1
fi

while true; do
  echo "The partition is now complete, please select the device you wish to install:"
  for i in "${!hosts[@]}"; do
    echo "$((i+1)). ${hosts[$i]}"
  done

  read -p $'\e[1;32mEnter your choice (number): \e[0m' -r choice

  # Validate choice
  if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#hosts[@]}" ]; then
    echo "❌ Invalid choice, please try again."
    continue
  fi

  selected_host="${hosts[$((choice-1))]}"
  
  # 2. Set password and update me.nix
  set_user_passwd
  echo "📝 Updating initialHashedPassword in me.nix..."
  sed -i "/initialHashedPassword/c\ \ \ \ initialHashedPassword\ =\ \"$passwd_hash\";" ./me.nix
  
  # 3. Execute installation
  echo "🚀 Starting nixos-install for $selected_host..."
  nixos-install --no-root-passwd --flake ".#$selected_host"
  break
done
