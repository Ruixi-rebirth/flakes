#!/usr/bin/env bash
# NixOS Rebuild Wrapper Script for Gemini CLI Skill
set -e

# Detect sudo/doas
if command -v doas &>/dev/null; then
  SUDO=doas
else
  SUDO=sudo
fi

# Function to show usage
usage() {
  echo "Usage: $0 [switch|test|boot|dry-activate] [host]"
  echo "Available hosts: k-on, minimal, yu"
  exit 1
}

# Get arguments
COMMAND=${1:-switch}
HOST=$2

# If host is not provided, try to detect it or ask
if [ -z "$HOST" ]; then
  CURRENT_HOSTNAME=$(hostname)
  if [[ " k-on minimal yu " =~ " $CURRENT_HOSTNAME " ]]; then
    HOST=$CURRENT_HOSTNAME
    echo "Detected current host: $HOST"
  else
    echo "Which device do you want to rebuild?"
    echo "1. k-on"
    echo "2. minimal"
    echo "3. yu"
    read -p "Enter your choice (number): " -r choice
    case $choice in
      1) HOST="k-on" ;;
      2) HOST="minimal" ;;
      3) HOST="yu" ;;
      *) echo "Invalid choice"; exit 1 ;;
    esac
  fi
fi

# Execute rebuild
echo "Executing: $SUDO nixos-rebuild $COMMAND --flake .#$HOST"
$SUDO nixos-rebuild "$COMMAND" --flake ".#$HOST"
