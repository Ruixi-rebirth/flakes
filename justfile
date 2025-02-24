# First, manually enter the `nix develop` environment, and then execute the `just <recipe>` command.

set shell := ["bash", "-uc"]

disko:
    echo "Running disko script..."
    bash ./lib/scripts/disko.sh

install:
    echo "Running install script..."
    bash ./lib/scripts/install.sh
