set -e

if command -v doas &>/dev/null; then
  PAMT=doas
else
  PAMT=sudo
fi

while true; do
  echo "Which device do you want to rebuild?"
  echo "1. k-on"
  echo "2. minimal"
  read -p $'\e[1;32mEnter your choice(number): \e[0m' -r device

  case $device in
  1)
    $PAMT nixos-rebuild switch --flake .#k-on
    break
    ;;
  2)
    $PAMT nixos-rebuild switch --flake .#minimal
    break
    ;;
  *)
    echo "Invalid choice, please try again."
    ;;
  esac
done
