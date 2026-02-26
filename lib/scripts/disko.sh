#!/usr/bin/env bash

set -e

# --- Configuration & Styling ---
FLAKE_ROOT="${FLAKE_ROOT:-$(pwd)}"
LAYOUT_DIR="$FLAKE_ROOT/lib/disko_layout"
LUKS_KEY_FILE="/tmp/secret.key"

# Colors
GREEN='\e[1;32m'
RED='\e[1;31m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m' # No Color

# Helper Functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

check_deps() {
  for cmd in nix jq nvim lsblk nixos-generate-config; do
    if ! command -v "$cmd" &>/dev/null; then
      error "Missing required command: $cmd"
    fi
  done
}

ask_edit() {
  local file="$1"
  while true; do
    read -p "Would you like to edit this layout? (y/n): " choice
    [[ $choice == "y" ]] && nvim "$file" && break
    [[ $choice == "n" ]] && break
    warn "Invalid input, please enter 'y' or 'n'."
  done
}

review_and_edit() {
  local file="$1"
  clear
  echo -e "${GREEN}--- Reviewing Partition Layout: $(basename "$file") ---${NC}"
  cat "$file" | less

  while true; do
    read -p "Edit this layout again? (y/n): " choice
    [[ $choice == "y" ]] && nvim "$file" && break
    [[ $choice == "n" ]] && break
    warn "Invalid input."
  done
}

# --- Execution Starts Here ---
check_deps

# 1. Host Discovery
info "Scanning for NixOS configurations..."
hosts=($(nix --extra-experimental-features "nix-command flakes" flake show --json 2>/dev/null | jq -r '.nixosConfigurations | keys[]'))

if [ ${#hosts[@]} -eq 0 ]; then
  error "No NixOS configurations found in flake."
fi

echo -e "${BLUE}Select the target host configuration:${NC}"
for i in "${!hosts[@]}"; do
  echo "$((i + 1)). ${hosts[$i]}"
done
read -p "Choice (number): " host_idx
[[ ! $host_idx =~ ^[0-9]+$ ]] || [ "$host_idx" -lt 1 ] || [ "$host_idx" -gt "${#hosts[@]}" ] && error "Invalid host choice."
selected_host="${hosts[$((host_idx - 1))]}"

# 2. Layout Discovery
info "Scanning for disk layouts in $LAYOUT_DIR..."
layouts=($(ls "$LAYOUT_DIR"/*.nix))
if [ ${#layouts[@]} -eq 0 ]; then
  error "No layout files found in $LAYOUT_DIR."
fi

echo -e "${BLUE}Select a disk partition layout:${NC}"
for i in "${!layouts[@]}"; do
  echo "$((i + 1)). $(basename "${layouts[$i]}")"
done
read -p "Choice (number): " layout_idx
[[ ! $layout_idx =~ ^[0-9]+$ ]] || [ "$layout_idx" -lt 1 ] || [ "$layout_idx" -gt "${#layouts[@]}" ] && error "Invalid layout choice."
partition_layout="${layouts[$((layout_idx - 1))]}"

# 3. Handle LUKS if applicable
if [[ "$(basename "$partition_layout")" == *"luks"* ]]; then
  read -p $'\e[1;31mEnter LUKS password (will be stored in /tmp/secret.key): \e[0m' -r luks_pass
  echo -n "$luks_pass" >"$LUKS_KEY_FILE"
  chmod 600 "$LUKS_KEY_FILE"
  success "LUKS key prepared."
fi

# 4. Review & Final Confirmation
ask_edit "$partition_layout"
review_and_edit "$partition_layout"

echo -e "${RED}--- CRITICAL: FINAL CONFIRMATION ---${NC}"
echo -e "Target Host:   ${YELLOW}$selected_host${NC}"
echo -e "Layout File:   ${YELLOW}$(basename "$partition_layout")${NC}"
echo -e "Operation:     ${RED}WIPE DISK AND INSTALL PARTITIONS${NC}"
warn "This action is IRREVERSIBLE. Ensure the device path in the Nix file is correct."
read -p "Type 'YES' to proceed: " final_confirm
[[ $final_confirm != "YES" ]] && error "Operation aborted by user."

# 5. Run Disko
info "Executing Disko..."
nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko "$partition_layout"

# 6. File System Preparation (Impermanence Support)
info "Preparing mount points for $selected_host..."
mkdir -p /mnt/etc/nixos
mkdir -p /mnt/nix/persist/etc/nixos
mount -o bind /mnt/nix/persist/etc/nixos /mnt/etc/nixos

# 7. Hardware Configuration
info "Generating hardware-configuration.nix..."
nixos-generate-config --no-filesystems --root /mnt
cd /mnt/etc/nixos

host_dir="$FLAKE_ROOT/hosts/$selected_host"
mkdir -p "$host_dir"
cp hardware-configuration.nix "$host_dir/hardware-configuration.nix"

# Patch hardware-configuration.nix to import the layout
layout_filename="$(basename "$partition_layout")"
relative_path="../../lib/disko_layout"
layout_import_path="$relative_path/$layout_filename"

info "Patching hardware-configuration.nix with disko layout..."
sed -i "/imports\ =/cimports\ = [\ $layout_import_path\ ]++" "$host_dir/hardware-configuration.nix"

# 8. Copy Flake to Target
info "Copying flake to /mnt/etc/nixos/flakes..."
mkdir -p /mnt/etc/nixos/flakes
cp -r "$FLAKE_ROOT"/* /mnt/etc/nixos/flakes/

# Cleanup sensitive data
if [ -f "$LUKS_KEY_FILE" ]; then
  rm "$LUKS_KEY_FILE"
  info "Cleaned up temporary LUKS key."
fi

lsblk
success "Disk preparation for $selected_host is COMPLETE!"
