#!/usr/bin/env bash

# This script updates Nix flake inputs based on user selection.
# It uses 'nix flake metadata' to list inputs and 'nix flake lock' to perform updates.

# Standard ANSI Color Codes
CYAN='\033[1;36m'  # Bold Cyan
GREEN='\033[1;32m' # Bold Green
NC='\033[0m'       # No Color

function list_inputs() {
  # Extract inputs and suppress stderr
  inputs=$(nix flake metadata --json 2>/dev/null | jq -r '.locks.nodes.root.inputs | keys[]' | sort | tr '\n' ' ')

  # Simple, Bold Header
  echo -e "\n${GREEN}Available Flake Inputs:${NC}"

  if [ -z "$inputs" ]; then
    echo "  (No inputs found)"
  else
    # Print inputs in Bold Cyan
    echo -e "  ${CYAN}${inputs}${NC}\n"
  fi
}

function update_input() {
  local input=$1
  if [ "$input" == "all" ]; then
    echo "Updating all flake inputs..."
    nix flake update
  else
    echo "Updating flake input: $input"
    nix flake lock --update-input "$input"
  fi
}

case "$1" in
list)
  list_inputs
  ;;
update)
  shift
  for input in "$@"; do
    update_input "$input"
  done
  ;;
*)
  echo "Usage: $0 {list|update [input1 input2 ...|all]}"
  exit 1
  ;;
esac
