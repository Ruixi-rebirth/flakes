#!/usr/bin/env bash
# NixOS Rebuild Wrapper Script for Gemini CLI Skill
set -e

# Detect sudo/doas
if command -v doas &>/dev/null; then
  SUDO=doas
else
  SUDO=sudo
fi

# 1. Validate the flake configuration
echo "🔍 Validating flake configuration..."
nix flake check

# 2. Format the code
echo "🎨 Formatting code..."
nix fmt

# 3. Dynamically discover hosts
echo "🕵️ Discovering hosts..."
# Extract hosts dynamically
hosts=($(nix flake show --json 2>/dev/null | jq -r '.nixosConfigurations | keys[]'))

if [ ${#hosts[@]} -eq 0 ]; then
  echo "❌ No NixOS configurations found in flake."
  exit 1
fi

# Function to show usage
usage() {
  echo "Usage: $0 [switch|test|boot|dry-activate] [host]"
  echo "Available hosts from flake: ${hosts[*]}"
  exit 1
}

# Get arguments
COMMAND=${1:-switch}
HOST=$2

# If host is not provided, try to detect it or ask
if [ -z "$HOST" ]; then
  CURRENT_HOSTNAME=$(hostname)
  
  # Check if current hostname is one of the hosts in the flake
  found=false
  for h in "${hosts[@]}"; do
    if [ "$h" == "$CURRENT_HOSTNAME" ]; then
      HOST=$CURRENT_HOSTNAME
      found=true
      echo "Detected current host: $HOST"
      break
    fi
  done

  if [ "$found" == "false" ]; then
    echo "Which device do you want to rebuild?"
    for i in "${!hosts[@]}"; do
      echo "$((i+1)). ${hosts[$i]}"
    done
    read -p "Enter your choice (number): " -r choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#hosts[@]}" ]; then
      echo "❌ Invalid choice"
      exit 1
    fi
    HOST="${hosts[$((choice-1))]}"
  fi
fi

# Execute rebuild
echo "🚀 Executing: $SUDO nixos-rebuild $COMMAND --flake .#$HOST"
$SUDO nixos-rebuild "$COMMAND" --flake ".#$HOST"
